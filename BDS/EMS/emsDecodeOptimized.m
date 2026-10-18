function [decodedCodeword, realIter] = emsDecodeOptimized(llrMatrix, settings)
% =========================================================================
% FUNCTION: emsDecodeOptimized (High-Speed Engineering Version)
%
% INPUTS:
%   llrMatrix : [numVarNodes x gfSize] Initial Channel LLRs.
%   settings  : Configuration structure.
% =========================================================================

    %% 1. Initialization & Graph Setup ====================================
    switch settings.messageType
        case 'B1C_2', [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_2();
        case 'B1C_3', [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_3();
        case 'B2a',   [hIndexCell, hElementCell, hMatrix] = getHInformationB2a();
        case 'B2b',   [hIndexCell, hElementCell, hMatrix] = getHInformationB2b();
        otherwise, error('emsDecode: Unknown messageType "%s"', settings.messageType);
    end
    
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    numVarNodes = settings.colH;
    numCheckNodes = settings.rowH;
    
    % --- Pre-compute Adjacency Lists ---
    cnConnections = cell(numCheckNodes, 1);
    for j = 1:numCheckNodes, cnConnections{j} = find(rowIndices == j); end
    
    vnConnections = cell(numVarNodes, 1);
    for i = 1:numVarNodes, vnConnections{i} = find(colIndices == i); end

    %% 2. Memory Allocation & State Initialization ========================
    
    % [CRITICAL LOGIC 1]: Mutable LLR Matrix for History Accumulation
    currentLlrMatrix = llrMatrix; 
    
    [~, minIndices] = min(currentLlrMatrix, [], 2); 
    decodedCodeword = (minIndices - 1)';
    
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'single');
    
    % Initialize V2C messages
    for i = 1:numEdges
        vnIdx  = colIndices(i);
        weight = edgeWeights(i);
        varToCheckMsg(i, :) = permuteV2C(weight, currentLlrMatrix(vnIdx, :), settings.gfMulTable);
    end
    
    realIter = settings.maxIterations;
    
    %% 3. Iterative Decoding Loop =========================================
    for iter = 1:settings.maxIterations  
        
        % --- A. Syndrome Check ---
        codewordGf = gf(decodedCodeword, settings.gfBits);        
        hMatrixGf  = gf(hMatrix.', settings.gfBits); 
        syndrome   = codewordGf * hMatrixGf;
        
        if all(syndrome == 0)
             realIter = iter;
             break;
        end
        
        % =================================================================
        % --- B. Check Node Update (Forward-Backward Optimized) ---
        % =================================================================
        % This section keeps the O(N) complexity speed advantage
        for j = 1:numCheckNodes
            connectedEdges = cnConnections{j};
            dc = length(connectedEdges); 
            
            % 1. Gather V2C messages
            v2c_msgs = zeros(dc, settings.gfSize);
            for k = 1:dc
                v2c_msgs(k, :) = varToCheckMsg(connectedEdges(k), :);
            end
            
            % 2. Forward Pass
            forward = cell(dc, 1);
            forward{1} = v2c_msgs(1, :);
            for k = 2:dc
                forward{k} = extMinSum(forward{k-1}, v2c_msgs(k, :), settings);
            end
            
            % 3. Backward Pass
            backward = cell(dc, 1);
            backward{dc} = v2c_msgs(dc, :);
            for k = (dc-1):-1:1
                backward{k} = extMinSum(backward{k+1}, v2c_msgs(k, :), settings);
            end
            
            % 4. Merge & Generate C2V
            for k = 1:dc
                targetEdgeIdx = connectedEdges(k);
                
                if k == 1
                    aggregatedLlr = backward{2};
                elseif k == dc
                    aggregatedLlr = forward{dc-1};
                else
                    aggregatedLlr = extMinSum(forward{k-1}, backward{k+1}, settings);
                end
                
                % Normalize
                aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
                
                % Permute to Variable Node domain
                weight = edgeWeights(targetEdgeIdx);
                checkToVarMsg(targetEdgeIdx, :) = permuteC2V(weight, aggregatedLlr, settings.gfMulTable);
            end
        end
         
        % =================================================================
        % --- C. Variable Node Update (Engineering Logic) ---
        % =================================================================
        % [CRITICAL LOGIC 2]: Calculate V2C based on ACCUMULATED history
        
        for i = 1:numVarNodes
            connectedEdges = vnConnections{i};
            
            % Get the current "polluted" base LLR
            baseLlr = currentLlrMatrix(i, :);
            
            for k = 1:length(connectedEdges)
                targetEdgeIdx = connectedEdges(k);
                
                % TempPosterior = Base + Sum(Incoming C2V) - Self_C2V
                % Note: Base already contains previous history, we add current 
                % C2V neighbors to form the Extrinsic info for the next round.
                tempPosterior = baseLlr;
                
                for m = 1:length(connectedEdges)
                    sourceEdgeIdx = connectedEdges(m);
                    if sourceEdgeIdx ~= targetEdgeIdx
                        tempPosterior = tempPosterior + checkToVarMsg(sourceEdgeIdx, :);
                    end
                end
                
                tempPosterior = tempPosterior - min(tempPosterior);
                weight = edgeWeights(targetEdgeIdx);
                varToCheckMsg(targetEdgeIdx, :) = permuteV2C(weight, tempPosterior, settings.gfMulTable);
            end
        end
        
        % =================================================================
        % --- D. LLR Accumulation (The "Pollution" Step) ---
        % =================================================================
        % [CRITICAL LOGIC 3]: Permanently modify LLR matrix with C2V
        
        for i = 1:numVarNodes
            connectedEdges = vnConnections{i};
            
            % Integrate C2V messages into the master LLR matrix
            for k = 1:length(connectedEdges)
                edgeIdx = connectedEdges(k);
                currentLlrMatrix(i, :) = currentLlrMatrix(i, :) + checkToVarMsg(edgeIdx, :);
            end
            
            % Normalize to prevent overflow
            currentLlrMatrix(i, :) = currentLlrMatrix(i, :) - min(currentLlrMatrix(i, :));
            
            % Hard Decision based on accumulated LLRs
            [~, minIdx] = min(currentLlrMatrix(i, :));
            decodedCodeword(i) = minIdx - 1;
        end
    end
end