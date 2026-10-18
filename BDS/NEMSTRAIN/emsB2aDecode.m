function decodedCodeword = emsB2aDecode(llrMatrix, settings)
% =========================================================================
% FUNCTION: emsB2aDecode
% DESCRIPTION:
%   Performs Extended Min-Sum (EMS) decoding specifically for the BDS B2a 
%   signal structure.
%
%   The decoder iterates between Variable Nodes (VN) and Check Nodes (CN)
%   to refine the reliability of GF symbols.
%
% INPUTS:
%   llrMatrix : [numVarNodes x gfSize] Initial Channel LLRs (Intrinsic).
%   settings  : Configuration structure (gfMulTable, maxIterations, etc.).
%
% OUTPUTS:
%   decodedCodeword : [1 x numVarNodes] Hard-decision decoded symbols.
% =========================================================================

    %% ================= 1. Initialization =================
    
    % Load B2a specific Parity Check Matrix
    % Note: Ensure you have implemented this function similar to the B2b one
    [hIndexCell, hElementCell, hMatrix] = getHInformationB2a();
    
    % Initial Hard Decision (based on Channel LLR only)
    [~, minIndices] = min(llrMatrix, [], 2); 
    decodedCodeword = (minIndices - 1)'; 
    
    %% ================= 2. Graph Setup =================
    % Build Tanner Graph edges from compressed H matrix
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
        
        parityErrors = sum(syndrome ~= 0);
        
        % Log status
        if mod(iter, 5) == 0 || parityErrors == 0
            fprintf('[Iter %2d] B2a Parity Errors: %d\n', iter, parityErrors);
        end
        
        % Early termination
        if parityErrors == 0
             fprintf('>>> B2a Decoding Successful at Iteration %d\n', iter);
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
            aggregatedLlr = llrMatrix(colIndices(i), :); % Start with Intrinsic LLR
            
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
            % Start calculation fresh from Channel LLR (Intrinsic)
            currentTotalLlr = llrMatrix(i, :);
            
            % Sum all extrinsic information from Check Nodes
            for j = 1:numEdges
                if i == colIndices(j)
                    currentTotalLlr = currentTotalLlr + checkToVarMsg(j, :);
                end
            end
            
            % Normalize
            currentTotalLlr = currentTotalLlr - min(currentTotalLlr);
            
            % Hard Decision
            [~, minIdx] = min(currentTotalLlr);
            decodedCodeword(i) = minIdx - 1;
        end
    end
end