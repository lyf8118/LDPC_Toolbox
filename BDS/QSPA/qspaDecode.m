function [decodedCodeword, realIter] = qspaDecode(symbolProbabilities, settings)
% =========================================================================
% FUNCTION: qspaDecode
% DESCRIPTION:
%   Performs Q-ary Sum-Product Algorithm (QSPA) decoding.
%   Supports B1C/B2a/B2b signals via settings.messageType.
%   Uses direct access to settings structure for parameters.
%
% INPUTS:
%   symbolProbabilities : [settings.colH x settings.gfSize] Probability Matrix.
%   settings            : Configuration structure (must include gfMulTable, dimensions, etc.).
%
% OUTPUTS:
%   decodedCodeword     : [1 x settings.colH] Hard decision symbols.
% =========================================================================

    %% ================= Initialization & Graph Setup =================
    
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
            error('qspaDecode: Unknown messageType "%s"', settings.messageType);
    end

    % --- 1.2 Graph Properties ---
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % --- 1.3 Pre-compute Adjacency Lists ---
    % Variable Node Connections
    vnConnections = cell(settings.colH, 1);
    for i = 1:settings.colH
        vnConnections{i} = find(colIndices == i);
    end
    
    % Check Node Connections
    cnConnections = cell(settings.rowH, 1);
    for j = 1:settings.rowH
        cnConnections{j} = find(rowIndices == j);
    end
    
    % --- 1.4 Pre-compute Inverse Edge Weights ---
    % Find x such that weight * x = 1 (in GF) using the multiplication table
    invEdgeWeights = zeros(size(edgeWeights));
    for k = 1:numEdges
        w = edgeWeights(k);
        if w ~= 0
            % settings.gfMulTable row (w+1) contains results of w * x
            % Find column index where result is 1 (index 2 because value 1 is at index 2 for 0-based GF)
            % Note: In typical GF(64) poly, 1 is the multiplicative identity.
            % We look for value 1.
            invW = find(settings.gfMulTable(w + 1, :) == 1, 1) - 1;
            invEdgeWeights(k) = invW;
        end
    end

    %% ================= LLR Initialization =================
    % Convert Probability Domain to Log-Likelihood Ratio Domain
    intrinsicLlr = zeros(settings.colH, settings.gfSize, 'double');
    
    for i = 1:settings.colH
        % Avoid log(0)
        pSafe = symbolProbabilities(i, :) + eps; 
        % LLR(a) = log(P(a)) - log(P(0))
        pRef = pSafe(1); 
        intrinsicLlr(i, :) = log(pSafe) - log(pRef);
    end
    
    % Initialize Messages
    varToCheckMsg = zeros(numEdges, settings.gfSize, 'double'); % V2C
    checkToVarMsg = zeros(numEdges, settings.gfSize, 'double'); % C2V
    
    % Initial Hard Decision
    [~, maxIndices] = max(symbolProbabilities, [], 2);
    decodedCodeword = (maxIndices - 1).';
    
    % Initialize V2C with Intrinsic LLRs (Permuted)
    for i = 1:numEdges
        vnIdx  = colIndices(i);
        weight = edgeWeights(i);
        varToCheckMsg(i, :) = permuteLlr(intrinsicLlr(vnIdx, :), weight, settings.gfMulTable);
    end
   
    realIter = settings.maxIterations;

    %% ================= Iterative Decoding Loop =================
    for iter = 1:settings.maxIterations
        
        % ---  Syndrome Check ---
        codewordGf = gf(decodedCodeword, settings.gfBits);
        hMatrixGf  = gf(hMatrix.', settings.gfBits);
        syndrome   = codewordGf * hMatrixGf;
        
        if sum(syndrome ~= 0) == 0
            % Decoding successful
            realIter = iter;
            break;
        end
        
        % ---  Variable Node Update (VN) ---
        for i = 1:settings.colH
            edgeList = vnConnections{i};
            if isempty(edgeList), continue; end
            
             %  Compute Posterior: Intrinsic + Sum(All Incoming C2V)
            posterior = intrinsicLlr(i, :);
            for k = 1:length(edgeList)
                eIdx = edgeList(k);
                posterior = posterior + checkToVarMsg(eIdx, :);
            end
            
            %  Hard Decision
            [~, maxIdx] = max(posterior);
            decodedCodeword(i) = maxIdx - 1;
            
            %  Generate Outgoing V2C Messages
            for k = 1:length(edgeList)
                eIdx   = edgeList(k);
                weight = edgeWeights(eIdx);
                
                % Extrinsic: Posterior - Incoming C2V
                extrinsicMsg = posterior - checkToVarMsg(eIdx, :);
                
                % Permute and Store
                varToCheckMsg(eIdx, :) = permuteLlr(extrinsicMsg, weight, settings.gfMulTable);
            end
        end
        
        % ---  Check Node Update (CN) ---
        for j = 1:settings.rowH
            edgeList = cnConnections{j};
            numConn  = length(edgeList);
            if numConn < 2, continue; end
            
            % Gather Incoming V2C Messages
            msgs = zeros(numConn, settings.gfSize);
            for k = 1:numConn
                msgs(k, :) = varToCheckMsg(edgeList(k), :);
            end
            
            % Forward Recursion
            forward = zeros(numConn, settings.gfSize);
            forward(1, :) = msgs(1, :);
            for k = 2:numConn
                forward(k, :) = boxPlus(forward(k-1, :), msgs(k, :), settings.gfSize);
            end
            
            % Backward Recursion
            backward = zeros(numConn, settings.gfSize);
            backward(numConn, :) = msgs(numConn, :);
            for k = numConn-1:-1:1
                backward(k, :) = boxPlus(backward(k+1, :), msgs(k, :), settings.gfSize);
            end
            
            % Compute Outgoing C2V Messages & Inverse Permute
            for k = 1:numConn
                eIdx = edgeList(k);
                
                if k == 1
                    outputMsg = backward(2, :);
                elseif k == numConn
                    outputMsg = forward(numConn-1, :);
                else
                    outputMsg = boxPlus(forward(k-1, :), backward(k+1, :), settings.gfSize);
                end
                
                % Normalization (Stability)
                outputMsg = outputMsg - max(outputMsg);
                
                % Inverse Permutation: Apply h^-1
                invW = invEdgeWeights(eIdx);
                checkToVarMsg(eIdx, :) = permuteLlr(outputMsg, invW, settings.gfMulTable);
            end
        end
    end
end

