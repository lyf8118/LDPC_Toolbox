function decodedCodeword = emsB2bDecode(llrMatrix, settings)
% =========================================================================
% FUNCTION: emsB2bDecode
% DESCRIPTION:
%   Performs Extended Min-Sum (EMS) decoding for Non-Binary LDPC codes
%   configured for the BDS B2b signal.
%
%   The decoder uses an iterative message-passing algorithm on the Tanner
%   graph, exchanging messages between Variable Nodes (VN) and Check Nodes (CN).
%
% INPUTS:
%   llrMatrix : [numVarNodes x gfSize] Initial Log-Likelihood Ratio matrix.
%   settings  : Configuration structure containing system parameters.
%
% OUTPUTS:
%   decodedCodeword : [1 x numVarNodes] Decoded symbol sequence (Hard decision).
% =========================================================================

    %%  Initialization =====================================================
    
    % Load Parity Check Matrix (H) information
    % Note: Ensure 'getHInformationB2b.m' matches this function name
    [hIndexCell, hElementCell, hMatrix] = getHInformationB2b();

    % Perform initial hard decision based on channel LLRs
    % Find the index of the minimum LLR value (most likely symbol)
    [~, minIndices] = min(llrMatrix, [], 2); 
    decodedCodeword = (minIndices - 1)';   % Convert to 0-based GF symbol and transpose
    
    %% Graph Setup ========================================================
    % Establish edges for the Tanner Graph from compressed H matrix
    % rowIndices (ie): Check Node indices
    % colIndices (je): Variable Node indices
    % edgeWeights(he): GF edge weights
    % numEdges   (ne): Total number of edges
    % Note: Ensure 'getGraphEdges.m' matches this function name
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % Pre-allocate memory for message passing buffers
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'single'); % V2C Messages
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'single'); % C2V Messages

    % Initialize V2C messages using permuted intrinsic channel LLRs
    for i = 1:numEdges
        % Permute LLRs according to edge weight before sending to CN
        % Note: Ensure 'permuteV2C.m' matches this function name
        varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), llrMatrix(colIndices(i), :), settings.gfMulTable);
    end

    %%  Iterative Decoding Loop ===========================================
    for iter = 1:settings.maxIterations  
        
        % ---  Syndrome Check & Early Termination ---
        codewordGf = gf(decodedCodeword, settings.gfBits);        
        hMatrixGf  = gf(hMatrix.', settings.gfBits); 
        syndrome   = codewordGf * hMatrixGf;
        
        % Calculate number of unsatisfied parity checks
        parityErrors = sum(syndrome ~= 0);
        
        % Log status every 5 iterations or if zero errors found
        if mod(iter, 5) == 0 || parityErrors == 0
            fprintf('[Iter %2d] Parity Check Errors: %d\n', iter, parityErrors);
        end

        % Exit loop if codeword is valid (all parity checks satisfied)
        if parityErrors == 0
             fprintf('>>> Decoding Successful at Iteration %d\n', iter);
             break;
        end
        
        % ---  Check Node Update (Horizontal Step) ---
        % Update C2V messages using the Extended Min-Sum algorithm
        for i = 1:numEdges
            aggregatedLlr = [];
            
            % Aggregation: Collect V2C messages from all *other* edges connected to this CN
            for j = 1:numEdges
                if rowIndices(i) == rowIndices(j) && i ~= j
                    % Perform EMS check node operation
                    aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(j, :), settings);
                end
            end
            
            % Normalization and Permutation
            if ~isempty(aggregatedLlr)
                aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
                % Permute message back to Variable Node domain
                checkToVarMsg(i, :) = permuteC2V(edgeWeights(i), aggregatedLlr, settings.gfMulTable);
            end
        end
         
        % --- Variable Node Update (Vertical Step) ---
        % Update V2C messages by summing C2V messages
        for i = 1:numEdges
            aggregatedLlr = llrMatrix(colIndices(i), :); % Start with intrinsic LLR
            
            % Aggregation: Collect C2V messages from all *other* edges connected to this VN
            for j = 1:numEdges
                if colIndices(i) == colIndices(j) && i ~= j
                    aggregatedLlr = aggregatedLlr + checkToVarMsg(j, :);
                end
            end
            
            % Normalization and Permutation
            aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
            % Permute message to Check Node domain for next iteration
            varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), aggregatedLlr, settings.gfMulTable);
        end

        % --- 3.4 Posterior Probability Update & Hard Decision ---
        % Update the total LLR for each Variable Node
        for i = 1:settings.colH
            currentTotalLlr = llrMatrix(i, :);
            
            for j = 1:numEdges
                if i == colIndices(j)
                    % Add extrinsic information from all connected Check Nodes
                    currentTotalLlr = currentTotalLlr + checkToVarMsg(j, :);
                end
            end
            
            % Normalize total LLR
            currentTotalLlr = currentTotalLlr - min(currentTotalLlr);
            
            % Update the global LLR matrix (accumulating information over iterations)
            llrMatrix(i, :) = currentTotalLlr; 
            
            % Make hard decision based on updated LLR
            [~, minIdx] = min(currentTotalLlr);
            decodedCodeword(i) = minIdx - 1;
        end
    end
end