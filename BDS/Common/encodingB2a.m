function binaryCodeword = encodingB2a(infoSymbols)
% =========================================================================
% FUNCTION: encodingB2a
% DESCRIPTION:
%   Performs Non-Binary LDPC encoding for the BDS B2a signal.
%   Constructs the systematic codeword from the provided sparse Parity 
%   Check Matrix (H).
%
%   Systematic Encoding Strategy:
%   H = [H1 | H2], where H2 is square (48x48) and invertible.
%   Codeword C = [Information (u) | Parity (p)]
%   Constraint: H * C^T = 0  => H1*u^T + H2*p^T = 0
%   Solution:   p = u * (H2^-1 * H1)^T
%
% INPUTS:
%   infoSymbols     : [1 x 48] Array of information symbols (decimal).
%
% OUTPUTS:
%   binaryCodeword  : [96 x 6] Binary matrix (Rows = Symbols, Cols = Bits).
%   decimalCodeword : [1 x 96] Decoded symbols in decimal format.
% =========================================================================

    %% ================= 1. Configuration & Data Definition =================
    gfBits = 6;      % GF(2^6)
    
    % Raw Column Indices (0-based from spec)
    hIndicesRaw = [
        19 46 49 76; 22 41 68 94; 8 40 60 87; 5 38 70 89; 23 37 58 83; 6 30 54 76; 1 25 49 79; 8 36 51 84; 11 33 59 81; 16 31 65 73; 21 42 75 92; 4 39 71 88; ...
        5 29 53 71; 20 44 54 75; 15 26 66 81; 16 34 64 92; 15 43 56 91; 14 27 67 80; 12 27 69 79; 3 45 56 86; 20 43 74 93; 4 28 52 70; 7 31 55 77; 13 44 68 78; ...
        17 30 64 72; 9 41 61 86; 19 24 67 95; 21 45 55 74; 18 47 48 77; 17 47 65 93; 18 35 66 94; 0 29 62 85; 13 32 63 91; 1 28 63 84; 9 37 50 85; 3 27 51 73; ...
        22 36 59 82; 6 47 60 89; 2 26 50 72; 0 24 48 78; 14 42 57 90; 7 46 61 88; 23 40 69 95; 2 39 57 87; 11 35 52 83; 12 33 62 90; 10 34 53 82; 10 32 58 80
    ];

    % GF Element Values
    hElementsRaw = [
        1 45 15 6; 18 15 32 61; 24 1 44 53; 44 53 24 1; 45 15 6 1; 32 61 18 40; 30 24 1 44; 24 1 44 53; 1 45 15 6; 33 45 36 34; 44 35 31 50; 24 1 44 30; ...
        1 44 53 24; 3 55 9 34; 30 24 1 44; 39 36 34 33; 6 1 45 15; 1 45 15 6; 15 46 45 44; 15 6 1 45; 44 53 24 1; 6 1 45 15; 26 27 37 5; 24 1 44 30; ...
        45 15 6 1; 35 31 50 44; 32 42 47 37; 44 53 24 1; 24 1 44 53; 22 14 2 50; 45 15 6 1; 53 24 1 44; 57 25 9 41; 6 1 45 15; 24 1 44 30; 1 44 53 24; ...
        30 24 1 44; 45 15 6 1; 6 1 45 15; 44 53 24 1; 9 41 57 58; 24 1 44 30; 1 44 30 24; 7 38 23 54; 35 13 51 60; 6 1 45 15; 33 42 14 5; 1 44 30 24
    ];

    %% ================= 2. Matrix Reconstruction =================
    % Convert 0-based indices to 1-based (MATLAB standard)
    hIndices = hIndicesRaw + 1;
    
    % Initialize 48x96 Parity Check Matrix H
    hMatrix = zeros(48, 96);
    
    % Populate H Matrix
    [rows, cols] = size(hIndices);
    for i = 1:rows
        for j = 1:cols
            colIndex = hIndices(i, j);
            elementVal = hElementsRaw(i, j);
            hMatrix(i, colIndex) = elementVal;
        end
    end
    
    % Convert to Galois Field Object
    hMatrixGf = gf(hMatrix, gfBits);
    
    %% ================= 3. Encoding Calculation =================
    % H = [H1 | H2]
    h1 = hMatrixGf(:, 1:48);   % Information part connection
    h2 = hMatrixGf(:, 49:96);  % Parity part connection (Square, Invertible)
    
    % Compute Parity Generator Part: G2 = (H2^-1 * H1)^T
    % P = u * G2
    g2 = (h2 \ h1).'; 
    
    % Convert input to GF
    infoSeqGf = gf(infoSymbols, gfBits);
    
    % Calculate Parity Symbols
    paritySeqGf = infoSeqGf * g2;
    
    % Concatenate to form full codeword: [Info, Parity]
    codewordGf = [infoSeqGf, paritySeqGf];
    
    %% ================= 4. Output Formatting (Vectorized) =================
    % 1. Extract Decimal Values
    decimalCodeword = double(codewordGf.x); % [1 x 96]
    
    % 2. Convert to Binary Matrix
    % Transpose to column vector [96 x 1] -> dec2bin -> char matrix [96 x 6]
    % Subtract '0' to convert to double [0, 1]
    binaryCodeword = dec2bin(decimalCodeword.', gfBits) - '0';
    
end