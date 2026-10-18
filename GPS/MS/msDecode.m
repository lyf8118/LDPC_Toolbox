function [decodedCodeword,realIter] = msDecode(llr, settings)
% =========================================================================
% FUNCTION: msDecode
% DESCRIPTION:
%   Performs Min-Sum LDPC decoding for GPS L1C (CNAV-2).
%   Supports Standard MS, Normalized MS (alpha), and Offset MS (offset).
%
% INPUTS:
%   llr      : [N x 1] Log-Likelihood Ratios from channel.
%   settings : Structure containing configuration (messageType, maxIterations, 
%              alpha, offset, etc).
%
% OUTPUTS:
%   decodedCodeword : [N x 1] Hard decision bits (0 or 1).
%   realIter        : Actual number of iterations performed.
% =========================================================================

    %% Input Validation ===================================================
    llr = llr(:); % Ensure column vector
    
    %% Load Graph Structure (Smart Caching) ===============================
    % Use persistent variables to generate H and graph connections ONLY ONCE
    % or when the message type changes.
    persistent hMatrix numRows numCols numEdges
    persistent cnConnections vnConnections cachedMessageType
    
    if isempty(hMatrix) || ~strcmp(cachedMessageType, settings.messageType)
        
        fprintf('[-] Generating Min-Sum Graph for: %s\n', settings.messageType);
        cachedMessageType = settings.messageType;
        
        % Load Tables 
        gpsCnav2LdpcTables;
        
        % Dispatch Matrix Generation based on Message Type
        switch settings.messageType
            case 'L1C_2'
                % SF2: 600 x 1200
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF2_A, H_CNV2_SF2_B, H_CNV2_SF2_C, ...
                    H_CNV2_SF2_D, H_CNV2_SF2_E, H_CNV2_SF2_T);
            case 'L1C_3'
                % SF3: 274 x 548
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF3_A, H_CNV2_SF3_B, H_CNV2_SF3_C, ...
                    H_CNV2_SF3_D, H_CNV2_SF3_E, H_CNV2_SF3_T);
            otherwise
                error('msDecode: Unknown messageType "%s"', settings.messageType);
        end
        
        [numRows, numCols] = size(hMatrix);
        
        % Build Adjacency Lists (Optimization for loop speed)
        [rowIndices, colIndices] = find(hMatrix);
        numEdges = length(rowIndices);
        
        % Check Node Connections (Indices of edges connected to each Check Node)
        cnConnections = accumarray(rowIndices, (1:numEdges).', [numRows 1], @(y){y});
        
        % Variable Node Connections (Indices of edges connected to each Variable Node)
        vnConnections = accumarray(colIndices, (1:numEdges).', [numCols 1], @(y){y});
    end
    
    %% Initialization =====================================================
    % Message buffers
    varToChkMsg = zeros(numEdges, 1);   % V2C
    chkToVarMsg = zeros(numEdges, 1);   % C2V
    
    % Initialize V2C messages with intrinsic LLRs
    for j = 1:numCols
        edgeIndices = vnConnections{j};
        varToChkMsg(edgeIndices) = llr(j);
    end
    
    realIter = settings.maxIterations;
    
    %% Iterative Decoding Loop ============================================
    for iter = 1:settings.maxIterations
        
        % ---  Check Node Update (Scaled/Offset Min-Sum) ---
        for i = 1:numRows
            edgeIndices = cnConnections{i};
            degree = length(edgeIndices);
            
            if degree < 2
                chkToVarMsg(edgeIndices) = 0;
                continue;
            end
            
            % Get incoming V2C messages
            qMessages = varToChkMsg(edgeIndices);
            
            % Sign processing
            signVec = sign(qMessages);
            signVec(signVec == 0) = 1; % Handle 0 as positive to avoid NaN/Zero issues
            signProduct = prod(signVec);
            
            % Magnitude processing (Find min1 and min2)
            absQ = abs(qMessages);
            [min1, minIdx] = min(absQ);
            
            % Find second minimum efficiently
            absQ(minIdx) = inf; % Temporarily mask min1
            min2 = min(absQ);
            
            % =============================================================
            % [Modification] Apply Normalization or Offset to magnitudes
            % =============================================================
            if isfield(settings, 'offset') && settings.offset > 0
                % Offset Min-Sum (OMS)
                min1 = max(min1 - settings.offset, 0);
                min2 = max(min2 - settings.offset, 0);
            elseif isfield(settings, 'alpha') && settings.alpha < 1.0 && settings.alpha > 0
                % Normalized Min-Sum (NMS)
                min1 = min1 * settings.alpha;
                min2 = min2 * settings.alpha;
            end
            % =============================================================
            
            % Update C2V messages
            for k = 1:degree
                edgeIdx = edgeIndices(k);
                
                % Calculate sign for this specific edge (total_prod * own_sign)
                % Note: signProduct * signVec(k) is equivalent to total_prod / own_sign
                % because sign values are only +1 or -1.
                currentSign = signProduct * signVec(k);
                
                % Select magnitude (min2 if self is min1, else min1)
                if k == minIdx
                    currentMag = min2;
                else
                    currentMag = min1;
                end
                
                % Apply Final Message
                chkToVarMsg(edgeIdx) = currentSign * currentMag;
            end
        end
        
        % ---  Variable Node Update & Hard Decision ---
        posteriorLlr = llr; % Start with channel info
        
        % Sum incoming C2V messages (Vectorized by node)
        for j = 1:numCols
            edgeIndices = vnConnections{j};
            posteriorLlr(j) = posteriorLlr(j) + sum(chkToVarMsg(edgeIndices));
        end
        
        % Hard Decision (LLR < 0 -> bit 1)
        decodedCodeword = posteriorLlr < 0;
        
        % ---  Syndrome Check (Early Termination) ---
        syndrome = mod(hMatrix * decodedCodeword, 2);
        
        if ~any(syndrome)
            decodedCodeword = double(decodedCodeword);
            realIter = iter;
            return;
        end
        
        % ---  Update V2C for next iteration (Extrinsic) ---
        % V2C = Posterior - C2V_incoming
        for j = 1:numCols
            edgeIndices = vnConnections{j};
            % Subtract the message that came from the check node (extrinsic rule)
            varToChkMsg(edgeIndices) = posteriorLlr(j) - chkToVarMsg(edgeIndices);
        end
        
    end
    
    % If loop finishes without success, ensure output is double
    decodedCodeword = double(decodedCodeword);
end