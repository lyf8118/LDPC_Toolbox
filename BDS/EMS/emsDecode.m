function [decodedCodeword, realIter] = emsDecode(llrMatrix, settings)
% =========================================================================
% FUNCTION: emsDecode
% DESCRIPTION:
%   Performs Extended Min-Sum (EMS) decoding for Non-Binary LDPC codes.
%   Supports multiple signal types (B1C, B2a, B2b) via settings.messageType.
%
% INPUTS:
%   llrMatrix : [numVarNodes x gfSize] Initial Log-Likelihood Ratio matrix.
%   settings  : Configuration structure containing system parameters.
%
% OUTPUTS:
%   decodedCodeword : [1 x numVarNodes] Decoded symbol sequence (Hard decision).
%   realIter        : Actual number of iterations performed.
% =========================================================================

    %% 1. Initialization & Graph Setup ====================================
    
    % --- Load H Matrix based on Signal Type ---
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
            error('emsDecode: Unknown messageType "%s"', settings.messageType);
    end
    
    % --- Get Basic Graph Properties ---
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    numVarNodes = settings.colH;
    numCheckNodes = settings.rowH;
    
    % --- Pre-compute Adjacency Lists (Optimization Step) ---
    % Avoid inefficient lookup operations in loops, reducing complexity 
    % from O(E^2) to O(E).
    cnConnections = cell(numCheckNodes, 1);
    for j = 1:numCheckNodes
        cnConnections{j} = find(rowIndices == j);
    end
    
    vnConnections = cell(numVarNodes, 1);
    for i = 1:numVarNodes
        vnConnections{i} = find(colIndices == i);
    end

    %% 2. Memory Allocation & State Initialization ========================
    
    % [CRITICAL LOGIC]: We need a MUTABLE LLR matrix that accumulates history.
    currentLlrMatrix = llrMatrix; 
    
    % Initial Hard Decision
    [~, minIndices] = min(currentLlrMatrix, [], 2); 
    decodedCodeword = (minIndices - 1)'; 
    
    % Pre-allocate Message Memory
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'single'); % V2C messages
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'single'); % C2V messages
    
    % Initialize V2C messages with permuted initial LLRs
    for i = 1:numEdges
        vnIdx  = colIndices(i);
        weight = edgeWeights(i);
        varToCheckMsg(i, :) = permuteV2C(weight, currentLlrMatrix(vnIdx, :), settings.gfMulTable);
    end
    
    realIter = settings.maxIterations;

    %% 3. Iterative Decoding Loop =========================================
    for iter = 1:settings.maxIterations  
        
        % --- Syndrome Check & Early Termination ---
        codewordGf = gf(decodedCodeword, settings.gfBits);        
        hMatrixGf  = gf(hMatrix.', settings.gfBits); 
        syndrome   = codewordGf * hMatrixGf;
        
        if all(syndrome == 0)
             % Decoding successful
             realIter = iter;
             break;
        end
        
        % --- Check Node Update (Horizontal Step) ---
        for j = 1:numCheckNodes
            connectedEdges = cnConnections{j};
            
            % Iterate through every edge connected to this check node
            for k = 1:length(connectedEdges)
                targetEdgeIdx = connectedEdges(k);
                aggregatedLlr = [];
                
                % Collect V2C messages from other edges
                for m = 1:length(connectedEdges)
                    sourceEdgeIdx = connectedEdges(m);
                    if sourceEdgeIdx ~= targetEdgeIdx
                        aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(sourceEdgeIdx, :), settings);
                    end
                end
                
                % Normalize and permute back to Variable Node domain (C2V)
                if isempty(aggregatedLlr)
                    aggregatedLlr = zeros(1, settings.gfSize, 'single');
                end
                aggregatedLlr = aggregatedLlr - min(aggregatedLlr);

                if isfield(settings, 'offset') && settings.offset > 0
                    aggregatedLlr = max(aggregatedLlr - settings.offset, 0);
                    
                elseif isfield(settings, 'alpha') && settings.alpha < 1.0
                    % settings.alpha = 1.0  ->  EMS
                    % settings.alpha = 0.8  ->  Normalize EMS
                    aggregatedLlr = aggregatedLlr * settings.alpha;
                else  

                end
                % Permute back to Variable Node domain
                weight = edgeWeights(targetEdgeIdx);
                checkToVarMsg(targetEdgeIdx, :) = permuteC2V(weight, aggregatedLlr, settings.gfMulTable);
            end
        end
         
        % --- Variable Node Update (Vertical Step) ---
        
        for i = 1:numVarNodes
            connectedEdges = vnConnections{i};
            
            % Retrieve the currently accumulated LLR base value for this variable node
            baseLlr = currentLlrMatrix(i, :);
            
            for k = 1:length(connectedEdges)
                targetEdgeIdx = connectedEdges(k);
                
                % Compute Extrinsic Info: Base value + Sum of all C2V (excluding self)
                % Logically equivalent to: Temporary Posterior - Input C2V of this edge
                tempPosterior = baseLlr;
                
                for m = 1:length(connectedEdges)
                    sourceEdgeIdx = connectedEdges(m);
                    % Accumulate all incoming C2V messages to form the update
                    if sourceEdgeIdx ~= targetEdgeIdx
                        tempPosterior = tempPosterior + checkToVarMsg(sourceEdgeIdx, :);
                    end
                end
                
                % Normalize and permute to Check Node domain 
                tempPosterior = tempPosterior - min(tempPosterior);
                weight = edgeWeights(targetEdgeIdx);
                varToCheckMsg(targetEdgeIdx, :) = permuteV2C(weight, tempPosterior, settings.gfMulTable);
            end
        end
        
        % --- LLR Accumulation & Hard Decision  ---
        
        for i = 1:numVarNodes
            connectedEdges = vnConnections{i};
            
            % Update master LLR matrix with new check node information
            for k = 1:length(connectedEdges)
                edgeIdx = connectedEdges(k);
                currentLlrMatrix(i, :) = currentLlrMatrix(i, :) + checkToVarMsg(edgeIdx, :);
            end
            
            % Normalize to prevent numerical overflow
            currentLlrMatrix(i, :) = currentLlrMatrix(i, :) - min(currentLlrMatrix(i, :));
            
            % Update hard decision based on new accumulated LLRs
            [~, minIdx] = min(currentLlrMatrix(i, :));
            decodedCodeword(i) = minIdx - 1;
        end
        
    end
end