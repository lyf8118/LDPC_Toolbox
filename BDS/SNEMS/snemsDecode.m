function [decodedCodeword, realIter] = snemsDecode(llrMatrix, settings, neuralParams)
% =========================================================================
% FUNCTION: snemsDecode (Shared Weights Inference Version)
% DESCRIPTION:
%   Neural-EMS decoder with Layer-Shared Weights (Type-1).
%   - Forward Pass Only (Inference).
%   - Weights are scalars per iteration (1 x 1 x Iter).
%   - Activation: Mix of Linear and Tanh.
% =========================================================================

    %% ================= 1. Initialization =================

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
    

    %% ================= 2. Decoding Setup =================
    intrinsicLlr = single(llrMatrix);
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsgRaw = zeros(numEdges, settings.gfSize, 'single');
    

    
    % Initial Hard Decision
    [~, minIndices] = min(intrinsicLlr, [], 2);
    decodedCodeword = uint8(minIndices - 1)';
    
    % Init V2C (Variable to Check Message)
    for i = 1:numEdges
        varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), intrinsicLlr(colIndices(i), :), settings.gfMulTable);
    end
    
    realIter = settings.maxIterations;

    %% ================= 3. Decoding Loop =================
    for iter = 1:settings.maxIterations
        itC2V = min(iter, size(neuralParams.c2vWeights, 3));
        itVN  = min(iter, size(neuralParams.vnWeights, 3));
        
        % --- [Layer-Shared] Fetch Scalar C2V Weight for this Layer ---
        w_scalar = neuralParams.c2vWeights(1, 1, itC2V); 
        
        % ------------------------------------------------------
        % 3.1 Check Node (CN) Update
        % ------------------------------------------------------
        for i = 1:numEdges
            aggregatedLlr = [];
            for j = 1:numEdges
                if rowIndices(i) == rowIndices(j) && i ~= j
                    % aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(j, :), settings);
                    aggregatedLlr = optExtMinSum(aggregatedLlr, varToCheckMsg(j, :), settings);
                end
            end
            if isempty(aggregatedLlr), continue; end
            
            % Normalization
            aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
            checkToVarMsgRaw(i, :) = permuteC2V(edgeWeights(i), aggregatedLlr, settings.gfMulTable);
            
            % Apply Mixed Activation with Shared Weight
            % Formula: 0.5 * w * x + 0.5 * tanh(w * x)
            val = w_scalar * checkToVarMsgRaw(i, :);
            checkToVarMsg(i, :) = 0.5 * val + 0.5 * tanh(val);
        end
        
        % ------------------------------------------------------
        % 3.2 Variable Node (VN) Update
        % ------------------------------------------------------
        totalLlr = intrinsicLlr;
        for i = 1:numEdges
            totalLlr(colIndices(i), :) = totalLlr(colIndices(i), :) + checkToVarMsg(i, :);
        end
        
        % Apply Shared Neural Weighting (Beta)
        beta = neuralParams.vnWeights(1, 1, itVN);
        posteriorLlr = intrinsicLlr + beta * (totalLlr - intrinsicLlr);
        posteriorLlr = posteriorLlr - min(posteriorLlr, [], 2);
        
        % ------------------------------------------------------
        % 3.3 Next V2C Message Generation
        % ------------------------------------------------------
        for i = 1:numEdges
            nextMsg = posteriorLlr(colIndices(i), :) - checkToVarMsg(i, :);
            nextMsg = nextMsg - min(nextMsg);
            varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), nextMsg, settings.gfMulTable);
        end
        
        % ------------------------------------------------------
        % 3.4 Syndrome Check (Early Termination)
        % ------------------------------------------------------
        [~, minIdx] = min(posteriorLlr, [], 2);
        decodedCodeword = uint8(minIdx - 1);
        
        codewordGf = gf(double(decodedCodeword)', settings.gfBits);
        hMatrixGf  = gf(hMatrix.', settings.gfBits);
        syndrome   = codewordGf * hMatrixGf; 
        parityErrors = sum(syndrome ~= 0);
        
        if parityErrors == 0
            realIter = iter;
             break;
        end
    end
    
    decodedCodeword = decodedCodeword';
end
