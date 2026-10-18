function decodedCodeword = emsB1CDecode(llrMatrix, settings)
% =========================================================================
% FUNCTION: emsB1cDecode
% DESCRIPTION:
%   Performs Extended Min-Sum (EMS) decoding for BDS B1C signals (Subframe 2 & 3).
%   It automatically dispatches the correct Parity Check Matrix based on the 
%   configuration.
%
% INPUTS:
%   llrMatrix : [numVarNodes x gfSize] Initial Channel LLRs.
%   settings  : Configuration structure.
%
% OUTPUTS:
%   decodedCodeword : [1 x numVarNodes] Hard-decision decoded symbols.
% =========================================================================

    %% ================= 1. Initialization =================
    
    % Select Matrix Info based on specific B1C sub-type
    switch settings.messageType
        case 'B1C_2'
            % Note: Ensure this function exists and follows camelCase
            [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_2();
        case 'B1C_3'
            [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_3();  
        otherwise
            error('emsB1cDecode: Unknown B1C type "%s"', settings.messageType);
    end

    % Initial Hard Decision
    [~, minIndices] = min(llrMatrix, [], 2); 
    decodedCodeword = (minIndices - 1)';          
    
    %% ================= 2. Graph Setup =================
    % Build Tanner Graph
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % Allocate Message Buffers
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'single'); % V2C
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'single'); % C2V
    
    % Initialize V2C messages with intrinsic LLRs
    for i = 1:numEdges
        varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), llrMatrix(colIndices(i), :), settings.gfMulTable);
    end

    %% ================= 3. Iterative Decoding =================
    for iter = 1:settings.maxIterations  
        
        % --- 3.1 Syndrome Check ---
        codewordGf = gf(decodedCodeword, settings.gfBits);       
        hMatrixGf  = gf(hMatrix.', settings.gfBits);  
        syndrome   = codewordGf * hMatrixGf;
        
        if all(syndrome == 0)
             fprintf('>>> B1C Decoding Successful at Iteration %d\n', iter);
             break;
        end
        
        % --- 3.2 Check Node Update (Horizontal) ---
        for i = 1:numEdges
            aggregatedLlr = [];
            
            % Collect V2C from other edges connected to this Check Node
            for j = 1:numEdges
                if rowIndices(i) == rowIndices(j) && i ~= j
                    aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(j, :), settings);
                end
            end
            
            % Normalize and Permute back to VN domain
            if ~isempty(aggregatedLlr)
                aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
                checkToVarMsg(i, :) = permuteC2V(edgeWeights(i), aggregatedLlr, settings.gfMulTable);
            end
        end
         
        % --- 3.3 Variable Node Update (Vertical) ---
        for i = 1:numEdges
            aggregatedLlr = llrMatrix(colIndices(i), :); % Start with Intrinsic
            
            % Collect C2V from other edges connected to this Variable Node
            for j = 1:numEdges
                if colIndices(i) == colIndices(j) && i ~= j
                    aggregatedLlr = aggregatedLlr + checkToVarMsg(j, :);
                end
            end
            
            % Normalize and Permute to CN domain
            aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
            varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), aggregatedLlr, settings.gfMulTable);
        end

        % --- 3.4 Posterior Update & Hard Decision ---
        for i = 1:settings.colH
            currentTotalLlr = llrMatrix(i, :);
            
            for j = 1:numEdges
                if i == colIndices(j)
                    % Sum Extrinsic Info
                    currentTotalLlr = currentTotalLlr + checkToVarMsg(j, :);
                end
            end
            
            % Normalize
            currentTotalLlr = currentTotalLlr - min(currentTotalLlr);
            
            % Update Global LLR Matrix (Accumulate for next iter)
            llrMatrix(i, :) = currentTotalLlr;
            
            % Hard Decision
            [~, minIdx] = min(currentTotalLlr);
            decodedCodeword(i) = minIdx - 1;
        end
    end
end