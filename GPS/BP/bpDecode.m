function [decodedCodeword, realIter] = bpDecode(llr, settings)
% =========================================================================
% FUNCTION: bpDecode
% DESCRIPTION:
%   Performs Binary LDPC decoding for GPS L1C (CNAV-2) using the 
%   Sum-Product Algorithm (SPA/BP) with forward-backward schedule.
%   Supports both Subframe 2 (L1C_2) and Subframe 3 (L1C_3).
%
% INPUTS:
%   llr      : [N x 1] Log-Likelihood Ratios from channel.
%   settings : Structure containing configuration (ldpcN, ldpcM, etc.).
%
% OUTPUTS:
%   decodedCodeword : [N x 1] Hard decision bits (0 or 1).
% =========================================================================

    %% Input Validation & Defaults ========================================
    % Ensure LLR is a column vector
    llr = llr(:);
    
    % Verify LLR length matches the settings
    if length(llr) ~= settings.ldpcN
        error('bpDecode: LLR length (%d) does not match settings.ldpcN=%d.', ...
            length(llr), settings.ldpcN);
    end

    %% Load Graph Structure (Smart Caching) ===============================
    % Using 'persistent' to store the graph structure. 
    persistent hMatrix numRows numCols numEdges
    persistent cnConnections vnConnections cachedMessageType
    
    % Check if cache is empty OR if the message type has changed
    if isempty(hMatrix) || ~strcmp(cachedMessageType, settings.messageType)
        
        %fprintf('[-] Generating LDPC H-Matrix for type: %s\n', settings.messageType);
        
        % Update the cache tag
        cachedMessageType = settings.messageType;
        
        % Load Tables (Ensure gpsCnav2LdpcTables.m is in path)
        % This script should provide H_CNV2_SF2_X and H_CNV2_SF3_X matrices
        gpsCnav2LdpcTables; 
        
        % Dispatch Matrix Generation based on Message Type
        switch settings.messageType
            case 'L1C_2'
                % GPS L1C Subframe 2: 600 x 1200
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF2_A, H_CNV2_SF2_B, H_CNV2_SF2_C, ...
                    H_CNV2_SF2_D, H_CNV2_SF2_E, H_CNV2_SF2_T);
                
            case 'L1C_3'
                % GPS L1C Subframe 3: 274 x 548
                % Note: Ensure your gpsCnav2LdpcTables.m defines these SF3 variables
                hMatrix = generateGpsL1cHMatrix(settings.ldpcM, settings.ldpcN, 1, ...
                    H_CNV2_SF3_A, H_CNV2_SF3_B, H_CNV2_SF3_C, ...
                    H_CNV2_SF3_D, H_CNV2_SF3_E, H_CNV2_SF3_T);
                    
            otherwise
                error('bpDecode: Unsupported messageType "%s"', settings.messageType);
        end
        
        [numRows, numCols] = size(hMatrix);
        
        % Build Adjacency Lists (Optimization for Sparse Matrices)
        [rowIndices, colIndices] = find(hMatrix);
        numEdges = length(rowIndices);
        
        % Check Node Connections (Indices of edges connected to each Check Node)
        cnConnections = accumarray(rowIndices, (1:numEdges).', [numRows 1], @(y){y});
        
        % Variable Node Connections (Indices of edges connected to each Variable Node)
        vnConnections = accumarray(colIndices, (1:numEdges).', [numCols 1], @(y){y});
    end

    %% Initialization =====================================================
    % Message buffers (Edges x 1)
    varToChkMsg = zeros(numEdges, 1);
    chkToVarMsg = zeros(numEdges, 1);
    
    % Initialize V2C messages with Channel LLRs
    % Algorithm starts by sending channel info from Variable Nodes to Check Nodes
    for j = 1:numCols
        edgeIndices = vnConnections{j};
        varToChkMsg(edgeIndices) = llr(j);
    end

    realIter = settings.maxIterations;

    %% Iterative Decoding Loop ============================================
    for iter = 1:settings.maxIterations
        
        % --- 1. Check Node Update (Horizontal Step) ---
        % Using Forward-Backward algorithm for stability and speed
        for i = 1:numRows
            edgeIndices = cnConnections{i};
            degree      = length(edgeIndices);
            
            if degree < 2, continue; end
            
            % Get incoming messages from Variable Nodes
            qMessages = varToChkMsg(edgeIndices);
            
            % Forward Pass
            forwardSum = zeros(degree, 1);
            forwardSum(1) = qMessages(1);
            for k = 2:degree
                forwardSum(k) = boxPlus(forwardSum(k-1), qMessages(k));
            end
            
            % Backward Pass
            backwardSum = zeros(degree, 1);
            backwardSum(degree) = qMessages(degree);
            for k = (degree-1):-1:1
                backwardSum(k) = boxPlus(qMessages(k), backwardSum(k+1));
            end
            
            % Compute Extrinsic C2V Messages
            for k = 1:degree
                edgeIdx = edgeIndices(k);
                if k == 1
                    chkToVarMsg(edgeIdx) = backwardSum(2);
                elseif k == degree
                    chkToVarMsg(edgeIdx) = forwardSum(degree-1);
                else
                    chkToVarMsg(edgeIdx) = boxPlus(forwardSum(k-1), backwardSum(k+1));
                end
            end
        end
        
        % --- 2. Variable Node Update & Hard Decision (Vertical Step) ---
        posteriorLlr = llr; % Start with intrinsic channel LLR
        
        % Sum incoming C2V messages for each Variable Node
        for j = 1:numCols
            edgeIndices = vnConnections{j};
            posteriorLlr(j) = posteriorLlr(j) + sum(chkToVarMsg(edgeIndices));
        end
        
        % Hard Decision (Negative logic: LLR < 0 implies bit 1, LLR > 0 implies bit 0)
        decodedCodeword = posteriorLlr < 0;
        
        % --- 3. Syndrome Check (Early Termination) ---
        syndrome = mod(hMatrix * decodedCodeword, 2);
        
        if ~any(syndrome)
            % Optional: fprintf('Iteration %d: Decoding successful\n', iter);
            realIter = iter;
            break;
        end
        
        % --- 4. Prepare V2C for Next Iteration ---
        % V2C = Posterior - Incoming C2V (Extrinsic information rule)
        for j = 1:numCols
            edgeIndices = vnConnections{j};
            varToChkMsg(edgeIndices) = posteriorLlr(j) - chkToVarMsg(edgeIndices);
        end
        
    end
    
    % Convert logical to double for output consistency
    decodedCodeword = double(decodedCodeword);
end