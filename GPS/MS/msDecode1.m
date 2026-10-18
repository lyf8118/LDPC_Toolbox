function [decodedCodeword, realIter] = msDecode1(llr, settings)
% =========================================================================
% FUNCTION: msDecode
% DESCRIPTION:
%   Performs Min-Sum LDPC decoding for GPS L1C (CNAV-2).
%   FULLY VECTORIZED VERSION.
%   Supports Standard MS, Normalized MS (alpha), and Offset MS (offset).
%
% INPUTS:
%   llr      : [N x 1] Log-Likelihood Ratios from channel.
%   settings : Structure containing configuration (ldpcN, maxIterations, alpha, offset).
%
% OUTPUTS:
%   decodedCodeword : [N x 1] Hard decision bits (0 or 1).
%   realIter        : Actual number of iterations performed.
% =========================================================================
    
    %% Input Validation ===================================================
    llr = llr(:);
    
    % -------- Persistent graph cache --------
    persistent hMatrix numRows numCols numEdges
    persistent cnConnections cachedMessageType
    persistent colIndices 
    
    if isempty(hMatrix) || ~strcmp(cachedMessageType, settings.messageType)
        cachedMessageType = settings.messageType;
        gpsCnav2LdpcTables;
        switch settings.messageType
            case 'L1C_2'
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF2_A, H_CNV2_SF2_B, H_CNV2_SF2_C, ...
                    H_CNV2_SF2_D, H_CNV2_SF2_E, H_CNV2_SF2_T);
            case 'L1C_3'
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF3_A, H_CNV2_SF3_B, H_CNV2_SF3_C, ...
                    H_CNV2_SF3_D, H_CNV2_SF3_E, H_CNV2_SF3_T);
        end
        [numRows, numCols] = size(hMatrix);
        
        % Edge list
        [rowIdx, colIndices] = find(hMatrix);
        numEdges = numel(rowIdx);
        
        % CN adjacency
        cnConnections = accumarray(rowIdx, (1:numEdges).', [numRows 1], @(x){x});
    end

    %% Pre-parse Offset and Alpha (Avoids isfield inside loop) ============
    useOffset = isfield(settings, 'offset') && settings.offset > 0;
    useAlpha  = isfield(settings, 'alpha') && settings.alpha < 1.0 && settings.alpha > 0;
    valOffset = 0; 
    valAlpha = 1;
    if useOffset, valOffset = settings.offset; end
    if useAlpha,  valAlpha  = settings.alpha;  end

    %% Decode =============================================================
    c2vMsg      = zeros(numEdges, 1);
    varToChkMsg = llr(colIndices);           % init V2C
    decodedCodeword = zeros(numCols, 1);
    realIter = settings.maxIterations;
    
    for iter = 1:settings.maxIterations
        % CN update (scaled/offset min-sum)
        for cn = 1:numRows
            eIdxs = cnConnections{cn};
            deg = numel(eIdxs);
            if deg < 2
                c2vMsg(eIdxs) = 0;
                continue;
            end
            
            q = varToChkMsg(eIdxs);
            
            % Sign processing
            sgn = sign(q); 
            sgn(sgn == 0) = 1;
            sgnAll = prod(sgn);
            
            % Magnitude processing
            a = abs(q);
            [min1, idx1] = min(a);
            a(idx1) = inf;
            min2 = min(a);
            
            % --- Apply Normalization or Offset ---
            if useOffset
                min1 = max(min1 - valOffset, 0);
                min2 = max(min2 - valOffset, 0);
            elseif useAlpha
                min1 = min1 * valAlpha;
                min2 = min2 * valAlpha;
            end
            % -------------------------------------
            
            % Vectorized assignment
            mag = min1 * ones(deg, 1);
            mag(idx1) = min2;
            
            rawMsg = (sgnAll .* sgn) .* mag;   % sign excluding self
            c2vMsg(eIdxs) = rawMsg;            % No neural weights here!
        end
        
        % VN update (Vectorized with accumarray)
        sumC2v = accumarray(colIndices, c2vMsg, [numCols 1], @sum, 0);
        lPost  = llr + sumC2v;
        decodedCodeword = double(lPost < 0);
        
        % Syndrome early stop
        if ~any(mod(hMatrix * decodedCodeword, 2))
            realIter = iter;
            break;
        end
        
        % Extrinsic
        varToChkMsg = lPost(colIndices) - c2vMsg;
    end
end