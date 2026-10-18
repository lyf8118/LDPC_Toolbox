function [decodedCodeword, neuralParams, lossHistory] = nemsDecode(llrMatrix, settings, neuralParams)
% =========================================================================
% FUNCTION: nemsDecode
% DESCRIPTION:
%   Neural-EMS decoder.  
% =========================================================================

    %% ================= 1. Initialization =================
    if nargin < 3 || isempty(neuralParams)
        neuralParams.c2vWeights = [];
        neuralParams.vnWeights  = [];
        neuralParams.isTrainMode = false;
    end
    
    % --- [FIX] Select Matrix Info based on messageType ---
    switch settings.messageType
        case 'B1C_2'
            [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_2();
        case 'B1C_3'
            [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_3();
        case 'B2a'
            [hIndexCell, hElementCell, hMatrix] = getHInformationB2a();
        case 'B2b'
            [hIndexCell, hElementCell, hMatrix] = getHInformationB2b();
        otherwise
            error('nemsDecode: Unknown messageType "%s"', settings.messageType);
    end
    
    % Build Graph
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % Init Weights if empty
    if isempty(neuralParams.c2vWeights)
        neuralParams.c2vWeights = ones(numEdges, 1, settings.maxIterations, 'single');
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
            error('nemsDecode: Training requires groundTruth.');
        end
        % Ensure labels are Column Vector [N x 1]
        correctSymbols = double(neuralParams.groundTruth(:)); 
        
        adamBeta1 = 0.9; adamBeta2 = 0.999; adamEps = 1e-8; adamTime = 0;
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
            
            w = neuralParams.c2vWeights(i, 1, itC2V);
            checkToVarMsg(i, :) = 0.5 * w * checkToVarMsgRaw(i, :) + 0.5 * tanh(w * checkToVarMsgRaw(i, :));
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
        
        % Syndrome Check
        codewordGf = gf(double(decodedCodeword)', settings.gfBits);
        hMatrixGf  = gf(hMatrix.', settings.gfBits);
        syndrome   = codewordGf * hMatrixGf; % 1xM vector
        parityErrors = sum(syndrome ~= 0);
        
        % 3.5 Training Step
        if neuralParams.isTrainMode
            % Softmax (Negate LLR for prob)
            stableLlr = -posteriorLlr - max(-posteriorLlr, [], 2);
            expVal = exp(stableLlr);
            probDist = expVal ./ sum(expVal, 2);
            
            % Loss CE
            flatIdx = sub2ind(size(probDist), (1:settings.colH)', correctSymbols + 1);
            lossCe = -mean(log(max(probDist(flatIdx), 1e-10)));
            
            % Loss Parity
            lossParity = mean(double(syndrome.x).^2);
            
            % Loss L2
            lossL2 = (1e-4/2) * sum((neuralParams.c2vWeights(:,1,iter)-1).^2);
            
            totalLoss = lossCe + 0.1 * lossParity + lossL2;
            lossHistory(iter) = totalLoss;
            
            % Gradients & Update
            gradPost = probDist;
            gradPost(flatIdx) = gradPost(flatIdx) - 1;
            gradPost = -gradPost / settings.colH;
            
            gradBeta = sum(gradPost .* (totalLlr - intrinsicLlr), 'all');
            
            gradW = zeros(numEdges, 1, 'single');
            for i = 1:numEdges
                w = neuralParams.c2vWeights(i, 1, iter);
                msg = checkToVarMsgRaw(i, :);
                deriv = 0.5 * msg .* (1 + (1 - tanh(w*msg).^2));
                gradW(i) = sum(gradPost(colIndices(i), :) .* (beta * deriv)) + 1e-4*(w-1);
            end
            
            % Adam Update (Simplified)
            adamTime = adamTime + 1;
            % Update W
            adamStateC2v.m(:,1,iter) = adamBeta1*adamStateC2v.m(:,1,iter) + (1-adamBeta1)*gradW;
            adamStateC2v.v(:,1,iter) = adamBeta2*adamStateC2v.v(:,1,iter) + (1-adamBeta2)*gradW.^2;
            mHat = adamStateC2v.m(:,1,iter)/(1-adamBeta1^adamTime);
            vHat = adamStateC2v.v(:,1,iter)/(1-adamBeta2^adamTime);
            neuralParams.c2vWeights(:,1,iter) = neuralParams.c2vWeights(:,1,iter) - neuralParams.learningRate * mHat ./ (sqrt(vHat)+adamEps);
            
            % Update Beta
            adamStateVn.m(1,1,iter) = adamBeta1*adamStateVn.m(1,1,iter) + (1-adamBeta1)*gradBeta;
            adamStateVn.v(1,1,iter) = adamBeta2*adamStateVn.v(1,1,iter) + (1-adamBeta2)*gradBeta^2;
            mHatB = adamStateVn.m(1,1,iter)/(1-adamBeta1^adamTime);
            vHatB = adamStateVn.v(1,1,iter)/(1-adamBeta2^adamTime);
            neuralParams.vnWeights(1,1,iter) = neuralParams.vnWeights(1,1,iter) - neuralParams.learningRate * mHatB ./ (sqrt(vHatB)+adamEps);
            
            % Clip
            neuralParams.c2vWeights(:,1,iter) = max(0.1, min(2.0, neuralParams.c2vWeights(:,1,iter)));
            neuralParams.vnWeights(1,1,iter)  = max(0.1, min(2.0, neuralParams.vnWeights(1,1,iter)));
            
            fprintf('[Iter %2d] Loss: %.4f (CE:%.4f P:%.4f) | Parity: %d\n', ...
                iter, totalLoss, lossCe, lossParity, parityErrors);
        elseif parityErrors == 0
             lossHistory(iter+1:end) = 0;
             break;
        end
    end
    decodedCodeword = decodedCodeword';
end
