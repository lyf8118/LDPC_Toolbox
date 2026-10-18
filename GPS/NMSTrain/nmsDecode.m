function [decodedCodeword, neuralParams, lossHistory] = nmsDecode(llr, settings, neuralParams)
% =========================================================================
% FUNCTION: nmsDecode (Type-3 Neural Min-Sum)
% DESCRIPTION:
%   Neural Min-Sum Decoder optimized for Irregular LDPC Codes.
%   Architecture: Type-3 (Weight sharing based on Check Node Degree)
%   Loss Function: BCEWithLogits (Sigmoid + Cross Entropy)
%   Fixed: 'beta1 undefined' error by moving parameter definition.
% =========================================================================

    %% 1. Input Validation
    llr = llr(:); 
    if length(llr) ~= settings.ldpcN
        error('nmsDecode: LLR length (%d) does not match settings.ldpcN=%d.', length(llr), settings.ldpcN);
    end

    %% 2. Graph Construction & Caching (Persistent)
    persistent hMatrix numRows numCols numEdges
    persistent cnConnections vnConnections cachedMessageType
    persistent colIndices cnDegrees  maxDegree rowIndices
    
    if isempty(hMatrix) || ~strcmp(cachedMessageType, settings.messageType)
        fprintf('[-] Generating Type-3 Graph for: %s\n', settings.messageType);
        cachedMessageType = settings.messageType;
        
        gpsCnav2LdpcTables; 
        switch settings.messageType
            case 'L1C_2'
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF2_A, H_CNV2_SF2_B, H_CNV2_SF2_C, ...
                    H_CNV2_SF2_D, H_CNV2_SF2_E, H_CNV2_SF2_T);
            case 'L1C_3'
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF3_A, H_CNV2_SF3_B, H_CNV2_SF3_C, ...
                    H_CNV2_SF3_D, H_CNV2_SF3_E, H_CNV2_SF3_T);
        end
        
        [numRows, numCols] = size(hMatrix);
        [rowIndices, colIndices] = find(hMatrix); 
        numEdges = length(rowIndices);
        
        % Build Standard Adjacency
        cnConnections = accumarray(rowIndices, (1:numEdges).', [numRows 1], @(y){y});
        vnConnections = accumarray(colIndices, (1:numEdges).', [numCols 1], @(y){y});
        
        % --- Type-3 Specific: Pre-calculate Degrees ---
        % Calculate degree for each Check Node
        cnDegrees = full(sum(hMatrix, 2)); % [Rows x 1]
        maxDegree = max(cnDegrees);
        
        % Build map: Degree -> List of Check Nodes with that degree
        degreeIdxMap = cell(maxDegree, 1);
        for d = 1:maxDegree
            degreeIdxMap{d} = find(cnDegrees == d);
        end
        fprintf('    Max Check Degree: %d\n', maxDegree);
    end

    %% 3. Weights & Optimizer Setup
    if nargin < 3 || isempty(neuralParams)
        neuralParams.isTrainMode = false;
        neuralParams.weights = [];
    end

    % --- Type-3 Weights: [MaxDegree x MaxIter] ---
    if isempty(neuralParams.weights)
        neuralParams.weights = 0.8 * ones(maxDegree, settings.maxIterations);
    end
    
    if size(neuralParams.weights, 1) < maxDegree
        error('Loaded weights dimension (%d) is smaller than graph max degree (%d).', ...
            size(neuralParams.weights, 1), maxDegree);
    end

    % Training Setup
    if neuralParams.isTrainMode
        if ~isfield(neuralParams, 'adam') || isempty(neuralParams.adam)
            neuralParams.adam.m = zeros(size(neuralParams.weights));
            neuralParams.adam.v = zeros(size(neuralParams.weights));
            neuralParams.adam.t = 0;
        end
        
        if ~isfield(neuralParams, 'learningRate')
            neuralParams.learningRate = 0.01;
        end
        
        targets = double(neuralParams.groundTruth(:));
    end

    %% 4. Decoding Loop
    varToChkMsg   = zeros(numEdges, 1);
    c2vMsg        = zeros(numEdges, 1);
    lossHistory   = zeros(settings.maxIterations, 1);
    
    % Init V2C with Channel LLR
    for j = 1:numCols
        eIdxs = vnConnections{j};
        varToChkMsg(eIdxs) = llr(j);
    end
    
    % Backprop Buffers
    if neuralParams.isTrainMode
        sgnMagHistory = zeros(numEdges, 1);
    end
    
    decodedCodeword = zeros(numCols, 1);

    for iter = 1:settings.maxIterations
        
        % --- 4.1 Check Node Update (Type-3 Scaled) ---
        for i = 1:numRows
            eIdxs = cnConnections{i};
            deg = length(eIdxs); 
            if deg < 2, c2vMsg(eIdxs)=0; continue; end
            
            q = varToChkMsg(eIdxs);
            
            % Min-Sum Processing
            sgnVec = sign(q); sgnVec(sgnVec==0)=1;
            sgnAll = prod(sgnVec);
            
            absQ = abs(q);
            [min1, idx1] = min(absQ);
            absQ(idx1) = inf;
            min2 = min(absQ);
            
            % Get Weight for this Degree
            w = neuralParams.weights(deg, iter);
            
            for k = 1:deg
                e = eIdxs(k);
                currSgn = sgnAll * sgnVec(k);
                currMag = (k==idx1)*min2 + (k~=idx1)*min1;
                rawMsg  = currSgn * currMag;
                
                if neuralParams.isTrainMode
                    sgnMagHistory(e) = rawMsg; 
                end
                
                % Apply Type-3 Weight
                c2vMsg(e) = w * rawMsg;
            end
        end

        % --- 4.2 Variable Node Update ---
        L_post = llr; 
        for j = 1:numCols
            eIdxs = vnConnections{j};
            L_post(j) = L_post(j) + sum(c2vMsg(eIdxs));
        end
        
        decodedCodeword = L_post < 0; 
        syndrome = mod(hMatrix * decodedCodeword, 2);
        
        % --- 4.3 Training Step (BCE Loss) ---
        if neuralParams.isTrainMode
            % A. BCEWithLogits Loss
            x = -L_post;     % Logits
            y = targets;     % True Labels (0 or 1)
            
            lossVal = max(x, 0) - x .* y + log(1 + exp(-abs(x)));
            currentLoss = mean(lossVal);
            lossHistory(iter) = currentLoss;
            
            % B. Gradients
            p_1 = 1 ./ (1 + exp(-x)); 
            d_x = (p_1 - y) / numCols; 
            d_L_post = -d_x;
            
            d_loss_d_c2v = d_L_post(colIndices);
            
            % Compute Gradients components
            grad_components = d_loss_d_c2v .* sgnMagHistory;
            
            % Vectorized Gradient Accumulation by Degree
            % rowIndices corresponds to edges' check nodes.
            % We get the degree of the CN for each edge.
            edgeDegrees = cnDegrees(rowIndices);
            
            % Accumulate gradients for each degree d
            current_layer_grads = accumarray(edgeDegrees, grad_components, [maxDegree 1]);
            
            % Add Regularization (L2 -> 0.8)
            lambda = 0.05; 
            reg_grad = 2 * lambda * (neuralParams.weights(:, iter) - 0.8);
            
            final_grad = current_layer_grads + reg_grad;
            
            % Gradient Clipping
            final_grad = max(-0.5, min(0.5, final_grad));
            
            % C. Adam Update
            beta1 = 0.9; 
            beta2 = 0.999; 
            epsVal = 1e-8;
            
            neuralParams.adam.t = neuralParams.adam.t + 1;
            t_step = neuralParams.adam.t;
            
            m = neuralParams.adam.m(:, iter);
            v = neuralParams.adam.v(:, iter);
            
            m = beta1 * m + (1-beta1) * final_grad;
            v = beta2 * v + (1-beta2) * (final_grad.^2);
            
            neuralParams.adam.m(:, iter) = m;
            neuralParams.adam.v(:, iter) = v;
            
            m_hat = m / (1 - beta1^t_step);
            v_hat = v / (1 - beta2^t_step);
            
            update_step = neuralParams.learningRate * m_hat ./ (sqrt(v_hat) + epsVal);
            neuralParams.weights(:, iter) = neuralParams.weights(:, iter) - update_step;
            
            % Clip Weights
            neuralParams.weights(:, iter) = max(0.1, min(1.5, neuralParams.weights(:, iter)));
            
        elseif ~any(syndrome)
            lossHistory(iter:end) = 0; 
            break;
        end

        % --- 4.4 Extrinsic Update ---
        for j = 1:numCols
            eIdxs = vnConnections{j};
            varToChkMsg(eIdxs) = L_post(j) - c2vMsg(eIdxs);
        end
    end
    
    decodedCodeword = double(decodedCodeword);
end