function [decodedCodeword, neuralParams, lossHistory] = snemsDecode(llrMatrix, settings, neuralParams)
% =========================================================================
% FUNCTION: snemsDecode (Shared Weights Version)
% DESCRIPTION:
%   Neural-EMS decoder with Layer-Shared Weights (Type-1).
%   Both C2V and V2C weights are now scalars per iteration.
% =========================================================================
    %% ================= 1. Initialization =================
    if nargin < 3 || isempty(neuralParams)
        neuralParams.c2vWeights = [];
        neuralParams.vnWeights  = [];
        neuralParams.isTrainMode = false;
    end
    
    % Select Matrix Info based on messageType
    switch settings.messageType
        case 'B1C_2', [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_2();
        case 'B1C_3', [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_3();
        case 'B2a',   [hIndexCell, hElementCell, hMatrix] = getHInformationB2a();
        case 'B2b',   [hIndexCell, hElementCell, hMatrix] = getHInformationB2b();
        otherwise, error('snemsDecode: Unknown messageType "%s"', settings.messageType);
    end
    
    % Build Graph
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % --- [MODIFIED] Weights are now Scalar (1 x 1 x Iter) ---
    if isempty(neuralParams.c2vWeights)
        % Before: ones(numEdges, 1, ...) -> Now: ones(1, 1, ...)
        neuralParams.c2vWeights = ones(1, 1, settings.maxIterations, 'single');
    end
    if isempty(neuralParams.vnWeights)
        neuralParams.vnWeights = ones(1, 1, settings.maxIterations, 'single');
    end
    if ~isfield(neuralParams, 'learningRate')
        neuralParams.learningRate = 1e-3;
    end
    
    % Adam State
    if neuralParams.isTrainMode
        if ~isfield(neuralParams, 'groundTruth')
            error('snemsDecode: Training requires groundTruth.');
        end
        correctSymbols = double(neuralParams.groundTruth(:)); 
        
        adamBeta1 = 0.9; adamBeta2 = 0.999; adamEps = 1e-8; adamTime = 0;
        
        % --- [MODIFIED] Adam buffers match scalar weights ---
        adamStateC2v.m = zeros(size(neuralParams.c2vWeights), 'single');
        adamStateC2v.v = zeros(size(neuralParams.c2vWeights), 'single');
        adamStateVn.m  = zeros(size(neuralParams.vnWeights), 'single');
        adamStateVn.v  = zeros(size(neuralParams.vnWeights), 'single');
    end
    
    %% ================= 2. Decoding Setup =================
    intrinsicLlr = single(llrMatrix);
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsgRaw = zeros(numEdges, settings.gfSize, 'single');
    lossHistory = zeros(settings.maxIterations, 1, 'single');
    
    % Initial Hard Decision
    [~, minIndices] = min(intrinsicLlr, [], 2);
    decodedCodeword = uint8(minIndices - 1)';
    
    % Init V2C
    for i = 1:numEdges
        varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), intrinsicLlr(colIndices(i), :), settings.gfMulTable);
    end
    
    %% ================= 3. Loop =================
    for iter = 1:settings.maxIterations
        itC2V = min(iter, size(neuralParams.c2vWeights, 3));
        itVN  = min(iter, size(neuralParams.vnWeights, 3));
        
        % --- [MODIFIED] Fetch Scalar C2V Weight for this Layer ---
        w_scalar = neuralParams.c2vWeights(1, 1, itC2V); 
        
        % 3.1 CN Update
        for i = 1:numEdges
            aggregatedLlr = [];
            for j = 1:numEdges
                if rowIndices(i) == rowIndices(j) && i ~= j
                    aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(j, :), settings);
                end
            end
            if isempty(aggregatedLlr), continue; end
            
            aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
            checkToVarMsgRaw(i, :) = permuteC2V(edgeWeights(i), aggregatedLlr, settings.gfMulTable);
            
            % Use shared w_scalar
            checkToVarMsg(i, :) = 0.5 * w_scalar * checkToVarMsgRaw(i, :) + 0.5 * tanh(w_scalar * checkToVarMsgRaw(i, :));
        end
        
        % 3.2 VN Update
        totalLlr = intrinsicLlr;
        for i = 1:numEdges
            totalLlr(colIndices(i), :) = totalLlr(colIndices(i), :) + checkToVarMsg(i, :);
        end
        
        beta = neuralParams.vnWeights(1, 1, itVN);
        posteriorLlr = intrinsicLlr + beta * (totalLlr - intrinsicLlr);
        posteriorLlr = posteriorLlr - min(posteriorLlr, [], 2);
        
        % 3.3 Next V2C
        for i = 1:numEdges
            nextMsg = posteriorLlr(colIndices(i), :) - checkToVarMsg(i, :);
            nextMsg = nextMsg - min(nextMsg);
            varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), nextMsg, settings.gfMulTable);
        end
        
        % 3.4 Syndrome
        [~, minIdx] = min(posteriorLlr, [], 2);
        decodedCodeword = uint8(minIdx - 1);
        
        codewordGf = gf(double(decodedCodeword)', settings.gfBits);
        hMatrixGf  = gf(hMatrix.', settings.gfBits);
        syndrome   = codewordGf * hMatrixGf; 
        parityErrors = sum(syndrome ~= 0);
        
        % 3.5 Training Step
        if neuralParams.isTrainMode
            % Softmax & Loss Calculation (Same as before)
            stableLlr = -posteriorLlr - max(-posteriorLlr, [], 2);
            expVal = exp(stableLlr);
            probDist = expVal ./ sum(expVal, 2);
            
            flatIdx = sub2ind(size(probDist), (1:settings.colH)', correctSymbols + 1);
            lossCe = -mean(log(max(probDist(flatIdx), 1e-10)));
            lossParity = mean(double(syndrome.x).^2);
            
            % [MODIFIED] L2 Loss for Scalar Weight
            lossL2 = (1e-4/2) * (w_scalar - 1).^2; 
            
            totalLoss = lossCe + 0.1 * lossParity + lossL2;
            lossHistory(iter) = totalLoss;
            
            % Gradients - Post & Beta (Same as before)
            gradPost = probDist;
            gradPost(flatIdx) = gradPost(flatIdx) - 1;
            gradPost = -gradPost / settings.colH;
            
            gradBeta = sum(gradPost .* (totalLlr - intrinsicLlr), 'all');
            
            % [MODIFIED] Accumulate Gradients for Shared C2V Weight
            gradW_accum = 0; % Initialize accumulator
            
            % Vectorized calculation is possible, but keeping loop for readability/consistency
            for i = 1:numEdges
                msg = checkToVarMsgRaw(i, :);
                % Derivative of activation function
                deriv = 0.5 * msg .* (1 + (1 - tanh(w_scalar * msg).^2));
                
                % Gradient contribution from this edge
                grad_edge = sum(gradPost(colIndices(i), :) .* (beta * deriv));
                
                % Accumulate
                gradW_accum = gradW_accum + grad_edge;
            end
            
            % Add L2 regularization gradient
            gradW_total = gradW_accum + 1e-4 * (w_scalar - 1);
            
            % Adam Update (Simplified)
            adamTime = adamTime + 1;
            
            % Update Shared C2V
            m = adamStateC2v.m(1,1,iter); 
            v = adamStateC2v.v(1,1,iter);
            
            m = adamBeta1 * m + (1-adamBeta1) * gradW_total;
            v = adamBeta2 * v + (1-adamBeta2) * gradW_total^2;
            
            adamStateC2v.m(1,1,iter) = m;
            adamStateC2v.v(1,1,iter) = v;
            
            mHat = m / (1 - adamBeta1^adamTime);
            vHat = v / (1 - adamBeta2^adamTime);
            
            neuralParams.c2vWeights(1,1,iter) = neuralParams.c2vWeights(1,1,iter) - ...
                neuralParams.learningRate * mHat / (sqrt(vHat) + adamEps);
            
            % Update Beta (Shared V2C) - No change in logic
            mB = adamStateVn.m(1,1,iter);
            vB = adamStateVn.v(1,1,iter);
            
            mB = adamBeta1 * mB + (1-adamBeta1) * gradBeta;
            vB = adamBeta2 * vB + (1-adamBeta2) * gradBeta^2;
            
            adamStateVn.m(1,1,iter) = mB;
            adamStateVn.v(1,1,iter) = vB;
            
            mHatB = mB / (1 - adamBeta1^adamTime);
            vHatB = vB / (1 - adamBeta2^adamTime);
            
            neuralParams.vnWeights(1,1,iter) = neuralParams.vnWeights(1,1,iter) - ...
                neuralParams.learningRate * mHatB / (sqrt(vHatB) + adamEps);
            
            % Clip Weights
            neuralParams.c2vWeights(1,1,iter) = max(0.1, min(2.0, neuralParams.c2vWeights(1,1,iter)));
            neuralParams.vnWeights(1,1,iter)  = max(0.1, min(2.0, neuralParams.vnWeights(1,1,iter)));
            
            fprintf('[Iter %2d] Loss: %.4f (CE:%.4f) | C2V: %.3f | V2C: %.3f\n', ...
                iter, totalLoss, lossCe, neuralParams.c2vWeights(1,1,iter), neuralParams.vnWeights(1,1,iter));
                
        elseif parityErrors == 0
             lossHistory(iter+1:end) = 0;
             break;
        end
    end
    decodedCodeword = decodedCodeword';
end
