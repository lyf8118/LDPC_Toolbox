function [decodedCodeword,realIter] = nmsDecode(llr, settings, neuralParams)
% =========================================================================
% FUNCTION: nmsDecode
% DESCRIPTION:
%   Performs Min-Sum LDPC decoding for GPS L1C (CNAV-2).
%   Supports both Subframe 2 and Subframe 3.
%
% INPUTS:
%   llr      : [N x 1] Log-Likelihood Ratios from channel.
%   settings : Structure containing configuration (ldpcN, maxIterations, etc).
%
% OUTPUTS:
%   decodedCodeword : [N x 1] Hard decision bits (0 or 1).
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

        % Max CN degree
    
        
    end

    %% Weights ============================================================
    weights = neuralParams.weights;   % expected size: [>=maxDegree, >=settings.maxIterations]

    %% Decode =============================================================
    c2vMsg      = zeros(numEdges, 1);
    varToChkMsg = llr(colIndices);           % init V2C
    decodedCodeword = zeros(numCols, 1);

    realIter = settings.maxIterations;

    for iter = 1:settings.maxIterations

        % CN update (scaled min-sum)
        for cn = 1:numRows
            eIdxs = cnConnections{cn};
            deg = numel(eIdxs);
            if deg < 2
                c2vMsg(eIdxs) = 0;
                continue;
            end

            q = varToChkMsg(eIdxs);

            sgn = sign(q); 
            sgn(sgn == 0) = 1;
            sgnAll = prod(sgn);

            a = abs(q);
            [min1, idx1] = min(a);
            a(idx1) = inf;
            min2 = min(a);

            mag = min1 * ones(deg, 1);
            mag(idx1) = min2;

            rawMsg = (sgnAll .* sgn) .* mag;   % sign excluding self
            w = weights(deg, iter);

            c2vMsg(eIdxs) = w * rawMsg;
        end

        % VN update
        sumC2v = accumarray(colIndices, c2vMsg, [numCols 1], @sum, 0);
        lPost  = llr + sumC2v;

        decodedCodeword = double(lPost < 0);

        % syndrome early stop
        if ~any(mod(hMatrix * decodedCodeword, 2))
            realIter = iter ;
            break;
        end

        % extrinsic
        varToChkMsg = lPost(colIndices) - c2vMsg;
    end
end
