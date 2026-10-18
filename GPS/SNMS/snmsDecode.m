function [decodedCodeword, neuralParams, lossHistory, realIter] = snmsDecode(llr, settings, neuralParams)
% =========================================================================
% FUNCTION: snmsDecode (Safety Valve Edition)
% DESCRIPTION: 
%   Includes Safety Clipping [0.2, 2.0] for Beta to prevent oscillation.
% =========================================================================

    %% 1. Initialization
    llr = llr(:);
    
    if nargin < 3 || isempty(neuralParams)
        neuralParams.c2vWeights = [];
        neuralParams.vnWeights  = [];
        neuralParams.isTrainMode = false;
    end
    
    % Default Fallback
    if isempty(neuralParams.c2vWeights)
        neuralParams.c2vWeights = 0.75 * ones(1, 1, settings.maxIterations, 'single');
    end
    if isempty(neuralParams.vnWeights)
        neuralParams.vnWeights = 1.0 * ones(1, 1, settings.maxIterations, 'single');
    end
    
    % Graph Caching
    persistent hMatrix numRows numCols numEdges cnConnections vnConnections cachedMessageType
    if isempty(hMatrix) || ~strcmp(cachedMessageType, settings.messageType)
        cachedMessageType = settings.messageType;
        gpsCnav2LdpcTables; 
        switch settings.messageType
            case 'L1C_2'
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF2_A, H_CNV2_SF2_B, H_CNV2_SF2_C, H_CNV2_SF2_D, H_CNV2_SF2_E, H_CNV2_SF2_T);
            case 'L1C_3'
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF3_A, H_CNV2_SF3_B, H_CNV2_SF3_C, H_CNV2_SF3_D, H_CNV2_SF3_E, H_CNV2_SF3_T);
        end
        [numRows, numCols] = size(hMatrix);
        [rowIndices, colIndices] = find(hMatrix);
        numEdges = length(rowIndices);
        cnConnections = accumarray(rowIndices, (1:numEdges).', [numRows 1], @(y){y});
        vnConnections = accumarray(colIndices, (1:numEdges).', [numCols 1], @(y){y});
    end
    
    % Adam Setup
    if neuralParams.isTrainMode
        groundTruth = double(neuralParams.groundTruth(:));
        adamBeta1 = 0.9; adamBeta2 = 0.999; adamEps = 1e-8; 
        if ~isfield(neuralParams.adamState, 'time'), neuralParams.adamState.time = 0; end
        neuralParams.adamState.time = neuralParams.adamState.time + 1;
        adamTime = neuralParams.adamState.time;
    end

    %% 2. Decoder Loop
    varToChkMsg = zeros(numEdges, 1);
    chkToVarMsg = zeros(numEdges, 1);
    chkToVarMsgRaw = zeros(numEdges, 1);
    lossHistory = zeros(settings.maxIterations, 1);
    
    % Init V2C
    for j = 1:numCols
        edgeIndices = vnConnections{j};
        varToChkMsg(edgeIndices) = llr(j);
    end
    decodedCodeword = llr < 0; 

    for iter = 1:settings.maxIterations
        
        itIdx = min(iter, size(neuralParams.c2vWeights, 3));
        alpha = neuralParams.c2vWeights(1, 1, itIdx); 
        beta  = neuralParams.vnWeights(1, 1, itIdx);  
        
        % --- 3.1 CN Update ---
        for i = 1:numRows
            edgeIndices = cnConnections{i};
            degree = length(edgeIndices);
            if degree < 2, continue; end
            
            qMessages = varToChkMsg(edgeIndices);
            signVec = sign(qMessages); signVec(signVec == 0) = 1; 
            signProduct = prod(signVec);
            absQ = abs(qMessages);
            [min1, minIdx] = min(absQ);
            absQ(minIdx) = inf; min2 = min(absQ);
            
            for k = 1:degree
                edgeIdx = edgeIndices(k);
                currentSign = signProduct * signVec(k);
                currentMag  = (k == minIdx) * min2 + (k ~= minIdx) * min1;
                rawMsg = currentSign * currentMag;
                chkToVarMsgRaw(edgeIdx) = rawMsg;      
                chkToVarMsg(edgeIdx) = alpha * rawMsg; 
            end
        end
        
        % --- 3.2 VN Update ---
        posteriorLlr = llr; 
        sumC2V = zeros(numCols, 1);
        for j = 1:numCols
            edgeIndices = vnConnections{j};
            sumC2V(j) = sum(chkToVarMsg(edgeIndices));
        end
        posteriorLlr = posteriorLlr + beta * sumC2V;
        decodedCodeword = posteriorLlr < 0;
        
        % --- 3.3 Syndrome & Early Exit ---
        syndrome = mod(hMatrix * decodedCodeword, 2);
        parityErrors = sum(syndrome);
        
        % --- 3.4 Training Step ---
        if neuralParams.isTrainMode
            p0 = 1 ./ (1 + exp(-posteriorLlr));
            target0 = 1 - groundTruth;
            baseBCE = -mean(target0 .* log(max(p0, 1e-10)) + (1-target0) .* log(max(1-p0, 1e-10)));
            
            % [核心修改 2]：温和的迭代惩罚
            % 从 1.0 到 1.3，不再过分惩罚
            iterPenalty = 1.0 + 0.3 * (iter / settings.maxIterations); 
            
            totalLoss = baseBCE * iterPenalty + 1e-6 * (alpha^2 + beta^2);
            lossHistory(iter) = totalLoss;
            
            % Gradients
            gradL_Post = ((p0 - target0) / numCols) * iterPenalty; 
            
            % dL/dBeta
            gradBeta = sum(gradL_Post .* sumC2V);
            
            % dL/dAlpha
            gradAlphaAccum = 0;
            for j = 1:numCols
                edgeIndices = vnConnections{j};
                g_j = gradL_Post(j) * beta; 
                gradAlphaAccum = gradAlphaAccum + sum(g_j .* chkToVarMsgRaw(edgeIndices));
            end
            
            % Update (Adam) - Beta
            neuralParams.adamState.mBeta(itIdx) = adamBeta1 * neuralParams.adamState.mBeta(itIdx) + (1-adamBeta1) * gradBeta;
            neuralParams.adamState.vBeta(itIdx) = adamBeta2 * neuralParams.adamState.vBeta(itIdx) + (1-adamBeta2) * gradBeta^2;
            mHatB = neuralParams.adamState.mBeta(itIdx) / (1 - adamBeta1^adamTime);
            vHatB = neuralParams.adamState.vBeta(itIdx) / (1 - adamBeta2^adamTime);
            neuralParams.vnWeights(itIdx) = neuralParams.vnWeights(itIdx) - neuralParams.learningRate * mHatB / (sqrt(vHatB) + adamEps);
            
            % Update (Adam) - Alpha
            neuralParams.adamState.mAlpha(itIdx) = adamBeta1 * neuralParams.adamState.mAlpha(itIdx) + (1-adamBeta1) * gradAlphaAccum;
            neuralParams.adamState.vAlpha(itIdx) = adamBeta2 * neuralParams.adamState.vAlpha(itIdx) + (1-adamBeta2) * gradAlphaAccum^2;
            mHatA = neuralParams.adamState.mAlpha(itIdx) / (1 - adamBeta1^adamTime);
            vHatA = neuralParams.adamState.vAlpha(itIdx) / (1 - adamBeta2^adamTime);
            neuralParams.c2vWeights(itIdx) = neuralParams.c2vWeights(itIdx) - neuralParams.learningRate * mHatA / (sqrt(vHatA) + adamEps);
            
            % [核心修改 3]：安全阀截断
            % Alpha: [0.5, 1.2]
            % Beta : [0.2, 2.0] (禁止超过 2.0)
            neuralParams.c2vWeights(itIdx) = max(0.6, min(1.0, neuralParams.c2vWeights(itIdx)));
            neuralParams.vnWeights(itIdx)  = max(0.5, min(1.5, neuralParams.vnWeights(itIdx)));
            
        elseif parityErrors == 0
            decodedCodeword = double(decodedCodeword);
            realIter = iter; % Return actual iterations
            return;
        end
        
        % --- 3.5 Extrinsic Update ---
        for j = 1:numCols
            edgeIndices = vnConnections{j};
            totalSum = sumC2V(j); 
            varToChkMsg(edgeIndices) = llr(j) + (totalSum - chkToVarMsg(edgeIndices));
        end
    end
    
    decodedCodeword = double(decodedCodeword);
    realIter = settings.maxIterations; % Max reached
end