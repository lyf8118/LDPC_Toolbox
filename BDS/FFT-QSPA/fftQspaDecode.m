function [decodedCodeword, realIter] = fftQspaDecode(symbolProbabilities, settings)
% =========================================================================
% FUNCTION: fftQspaDecode
% DESCRIPTION:
%   FFT-QSPA decoder for Non-Binary LDPC codes.
%   Uses Fast Walsh-Hadamard Transform (FWHT) to accelerate the Check Node
%   convolution operation.
%
% INPUTS:
%   symbolProbabilities : [colH x gfSize] Input Probability Matrix.
%   settings            : Configuration structure (must include gfMulTable).
%
% OUTPUTS:
%   decodedCodeword     : [1 x colH] Hard decision symbols.
% =========================================================================

    %%  Initialization & Graph Setup =========================================
    
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
            error('fftQspaDecode: Unknown messageType "%s"', settings.messageType);
    end

    % ---  Graph Properties ---
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    numVarNodes   = settings.colH;
    numCheckNodes = settings.rowH;
    gfSize        = settings.gfSize;
    gfBits        = settings.gfBits;
    
    % ---  Pre-compute Adjacency Lists (Optimization) ---
    % Variable Node Connections
    vnConnections = cell(numVarNodes, 1);
    for i = 1:numVarNodes
        vnConnections{i} = find(colIndices == i);
    end
    
    % Check Node Connections
    cnConnections = cell(numCheckNodes, 1);
    for j = 1:numCheckNodes
        cnConnections{j} = find(rowIndices == j);
    end
    
    % ---  Pre-compute Inverse Edge Weights ---
    % Find x such that weight * x = 1 (in GF) using the multiplication table
    invEdgeWeights = zeros(size(edgeWeights));
    for k = 1:numEdges
        w = edgeWeights(k);
        if w ~= 0
            % Row (w+1) contains w*x. Find index where result is 1.
            % (Index is 1-based, value is 0-based. If result is 1 (index 2))
            invW = find(settings.gfMulTable(w + 1, :) == 1, 1) - 1;
            invEdgeWeights(k) = invW;
        end
    end

    %%  LLR Initialization ================================================
    % Initialize Messages
    varToCheckMsg = zeros(numEdges, gfSize, 'double'); % V2C
    checkToVarMsg = zeros(numEdges, gfSize, 'double'); % C2V
    
    % Convert P -> LLR
    intrinsicLlr = zeros(numVarNodes, gfSize, 'double');
    for i = 1:numVarNodes
        pSafe = symbolProbabilities(i, :) + 1e-20; 
        pRef = pSafe(1); % Reference symbol 0
        intrinsicLlr(i, :) = log(pSafe) - log(pRef);
    end
    
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

    %%  Iterative Decoding Loop ===========================================
    for iter = 1:settings.maxIterations
        
        % ---  Syndrome Check ---
        codewordGf = gf(decodedCodeword, gfBits);
        hMatrixGf  = gf(hMatrix.', gfBits);
        syndrome   = codewordGf * hMatrixGf;
        
        if sum(syndrome ~= 0) == 0
            % fprintf('Iteration %d: Decoding successful\n', iter);
            realIter = iter;
            break;
        end
        
        % ---  Variable Node Update (VN) ---
        for i = 1:numVarNodes
            edgeList = vnConnections{i};
            if isempty(edgeList), continue; end
            
            % Aggregation: Intrinsic + Sum(Incoming C2V)
            % Optimized: Sum all C2V rows at once
            sumC2V = sum(checkToVarMsg(edgeList, :), 1);
            posterior = intrinsicLlr(i, :) + sumC2V;
            
            % Hard Decision
            [~, maxIdx] = max(posterior);
            decodedCodeword(i) = maxIdx - 1;
            
            % Update V2C Messages
            for k = 1:length(edgeList)
                eIdx   = edgeList(k);
                weight = edgeWeights(eIdx);
                
                % Extrinsic info
                msg = posterior - checkToVarMsg(eIdx, :);
                
                % Permute towards Check Node
                varToCheckMsg(eIdx, :) = permuteLlr(msg, weight, settings.gfMulTable);
            end
        end
        
        % ---  Check Node Update (CN) - FFT Accelerated ---
        for j = 1:numCheckNodes
            edgeList = cnConnections{j};
            if isempty(edgeList), continue; end
            
            %  Convert LLR -> Probability (Normalize)
            incomingLlr = varToCheckMsg(edgeList, :);
            % Shift LLRs to avoid exp() overflow
            maxLlr = max(incomingLlr, [], 2);
            incomingProb = exp(incomingLlr - maxLlr);
            % Normalize rows to sum to 1
            incomingProb = incomingProb ./ sum(incomingProb, 2);
            
            %  FWHT (Fast Walsh-Hadamard Transform)
            % Transforms convolution (GF add) into multiplication
            % fwht operates on columns, so we transpose
            spectrum = fwht(incomingProb.', gfSize, 'hadamard').';
            
            %  Compute Product in Transform Domain
            % Product of all incoming spectra
            totalProduct = prod(spectrum, 1);
            
            %  Compute Extrinsic Output for each edge
            % Division in transform domain
            % Handle division by zero/small numbers carefully
            outgoingSpectrum = zeros(size(spectrum));
            for k = 1:length(edgeList)
                % Avoid div by zero: add tiny epsilon or mask
                denom = spectrum(k, :);
                % Mask zeros to avoid NaN, they will be handled by inverse logic usually
                validMask = abs(denom) > 1e-15;
                
                outgoingSpectrum(k, validMask) = totalProduct(validMask) ./ denom(validMask);
                outgoingSpectrum(k, ~validMask) = 0; % Or handle small value logic
            end
            
            % Inverse FWHT
            outgoingProb = ifwht(outgoingSpectrum.', gfSize, 'hadamard').';
            
            % Numerical cleanup (Real part + Non-negative)
            outgoingProb = real(outgoingProb);
            outgoingProb = max(outgoingProb, 1e-40); % Avoid log(0)
            
            %  Convert Probability -> LLR
            p0 = outgoingProb(:, 1);
            outgoingLlr = log(outgoingProb) - log(p0);
            
            %  Update C2V Messages & Inverse Permutation
            for k = 1:length(edgeList)
                eIdx = edgeList(k);
                invW = invEdgeWeights(eIdx);
                
                % Inverse Permutation: Apply h^-1
                checkToVarMsg(eIdx, :) = permuteLlr(outgoingLlr(k, :), invW, settings.gfMulTable);
            end
        end
    end
    
    if iter == settings.maxIterations
        % fprintf('Decoding failed after %d iterations\n', settings.maxIterations);
    end
end