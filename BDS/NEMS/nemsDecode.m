function [decodedCodeword, realIter] = nemsDecode(llrMatrix, settings, neuralParams)
% =========================================================================
% FUNCTION: nemsDecode (Inference Only)
% DESCRIPTION:
%   Performs Neural-EMS decoding using pre-trained weights.
%   Supports B1C/B2a/B2b signals via settings.messageType.
% =========================================================================
    %% Initialization & Graph Setup =======================================
    
    % --- 1.1 Load H Matrix based on Signal Type ---
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
            error('neuralEmsDecode: Unknown messageType "%s"', settings.messageType);
    end
    
    % ---  Build Graph Properties ---
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % ---  Pre-compute Adjacency Lists (Optimization) ---
    % Pre-computing connections avoids O(E^2) loops
    
    % Check Node Connections
    cnConnections = cell(settings.rowH, 1);
    for j = 1:settings.rowH
        cnConnections{j} = find(rowIndices == j);
    end
    
    % Variable Node Connections
    vnConnections = cell(settings.colH, 1);
    for i = 1:settings.colH
        vnConnections{i} = find(colIndices == i);
    end
    % ---Handle Weights ---
    c2vWeights = single(neuralParams.c2vWeights);
    vnWeights  = single(neuralParams.vnWeights);
    
    %% Decoding Memory Allocation =========================================
    % Enforce single precision for speed
    intrinsicLlr = single(llrMatrix);
    
    % Buffers
    varToCheckMsg    = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsg    = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsgRaw = zeros(numEdges, settings.gfSize, 'single');
    
    % Initial Hard Decision
    [~, minIndices] = min(intrinsicLlr, [], 2);
    decodedCodeword = uint8(minIndices - 1)'; % [1 x N] Row Vector
    
    % Initialize V2C messages with permuted intrinsic LLRs
    for i = 1:numEdges
        vnIdx = colIndices(i);
        weight = edgeWeights(i);
        varToCheckMsg(i, :) = permuteV2C(weight, intrinsicLlr(vnIdx, :), settings.gfMulTable);
    end

    realIter = settings.maxIterations;

    %% Iterative Decoding Loop ============================================
    for iter = 1:settings.maxIterations
        
        % Get weights for current iteration (safeguard index)
        itC2V = min(iter, size(c2vWeights, 3));
        itVN  = min(iter, size(vnWeights, 3));
        
        % --- Syndrome Check (Early Termination) ---
        % [FIXED HERE] Removed the transpose ' inside double(...)
        % decodedCodeword is [1 x N], hMatrix.' is [N x M]
        % Result is [1 x M]
        codewordGf = gf(double(decodedCodeword), settings.gfBits);
        hMatrixGf  = gf(hMatrix.', settings.gfBits);
        syndrome   = codewordGf * hMatrixGf;
        
        if sum(syndrome ~= 0) == 0
            % Decoding Successful
            realIter = iter;
            break;
        end
        
        % ---  Check Node Update (Horizontal) ---
        for j = 1:settings.rowH
            connectedEdges = cnConnections{j};
            
            for k = 1:length(connectedEdges)
                targetEdgeIdx = connectedEdges(k);
                aggregatedLlr = [];
                
                % Collect V2C from *other* edges
                for m = 1:length(connectedEdges)
                    sourceEdgeIdx = connectedEdges(m);
                    if sourceEdgeIdx ~= targetEdgeIdx
                        %aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(sourceEdgeIdx, :), settings);
                        aggregatedLlr = optExtMinSum(aggregatedLlr, varToCheckMsg(sourceEdgeIdx, :), settings);
                    end
                end
                
                if isempty(aggregatedLlr), continue; end
                
                % Normalize
                aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
                
                % Permute to VN Domain (Raw C2V)
                weight = edgeWeights(targetEdgeIdx);
                rawMsg = permuteC2V(weight, aggregatedLlr, settings.gfMulTable);
                checkToVarMsgRaw(targetEdgeIdx, :) = rawMsg;
                
                % --- [Neural Step] Apply Nonlinear Weighting ---
                w = c2vWeights(targetEdgeIdx, 1, itC2V);
                
                % Activation: 0.5*w*x + 0.5*tanh(w*x)
                checkToVarMsg(targetEdgeIdx, :) = 0.5 * w * rawMsg + 0.5 * tanh(w * rawMsg);
            end
        end
        % --- Variable Node Update (Vertical) ---
        % Calculate Posterior and Next V2C
        
        % Temp buffer for new V2C
        nextVarToCheckMsg = varToCheckMsg;
        
        for i = 1:settings.colH
            connectedEdges = vnConnections{i};
            
            %  Compute Total LLR (intrinsic + all incoming C2V)
            totalLlr = intrinsicLlr(i, :);
            for k = 1:length(connectedEdges)
                edgeIdx = connectedEdges(k);
                totalLlr = totalLlr + checkToVarMsg(edgeIdx, :);
            end
            
            % --- [Neural Step] Apply Damping ---
            beta = vnWeights(1, 1, itVN);
            
            % Posterior = Intrinsic + Beta * ExtrinsicSum
            % (Note: TotalLlr - Intrinsic = ExtrinsicSum)
            posteriorLlr = intrinsicLlr(i, :) + beta * (totalLlr - intrinsicLlr(i, :));
            
            % Normalize Posterior
            posteriorLlr = posteriorLlr - min(posteriorLlr);
            
            %  Hard Decision Update
            [~, minIdx] = min(posteriorLlr);
            decodedCodeword(i) = minIdx - 1;
            
            %  Generate Outgoing V2C Messages
            for k = 1:length(connectedEdges)
                edgeIdx = connectedEdges(k);
                weight  = edgeWeights(edgeIdx);
                
                % Extrinsic: Posterior - Incoming C2V (from this edge)
                extrinsicMsg = posteriorLlr - checkToVarMsg(edgeIdx, :);
                extrinsicMsg = extrinsicMsg - min(extrinsicMsg);
                
                % Permute to CN Domain
                nextVarToCheckMsg(edgeIdx, :) = permuteV2C(weight, extrinsicMsg, settings.gfMulTable);
            end
        end
        
        % Update buffer
        varToCheckMsg = nextVarToCheckMsg;
        
    end
    
    % Ensure output format matches [1 x N]
    decodedCodeword = double(decodedCodeword);
end
