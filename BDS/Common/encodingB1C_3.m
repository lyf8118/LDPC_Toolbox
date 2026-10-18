function binaryCodeword = encodingB1C_3(infoSymbols)
% =========================================================================
% FUNCTION: encodingB1C_3
% DESCRIPTION:
%   Performs Non-Binary LDPC encoding for the B1C GNSS signal (Config 3).
%   Constructs the Generator Matrix (G) from the provided sparse Parity 
%   Check Matrix (H) and encodes the input decimal symbols.
%
%   Systematic Encoding:
%   H = [H1 | H2], where H2 is square (44x44) and invertible.
%   Systematic bits (u) + Parity bits (p).
%   p = u * (H2^-1 * H1)^T
%
% INPUTS:
%   infoSymbols    : [1 x 44] Array of information symbols (decimal).
%
% OUTPUTS:
%   binaryCodeword : [88 x 6] Binary matrix representing the encoded codeword.
%                    (Rows = Symbols, Cols = Bits per symbol).
% =========================================================================

    %% ================= 1. Configuration & Data Definition =================
    gfBits = 6;      % GF(2^6)
    
    % Raw Column Indices (0-based from spec)
    hIndicesRaw = [
        14, 35, 56, 70; 1, 27, 45, 54; 2, 26, 61, 79; 12, 38, 52, 68;
        17, 39, 44, 75; 17, 43, 67, 81; 0, 37, 70, 86; 18, 28, 67, 85;
        1, 36, 71, 87; 12, 37, 57, 83; 7, 25, 51, 60;
        11, 29, 55, 73; 23, 41, 63, 87; 9, 33, 59, 77; 23, 43, 58, 77;
        9, 35, 49, 72; 22, 40, 62, 86; 5, 31, 49, 75; 0, 26, 44, 55;
        16, 38, 45, 74; 6, 31, 51, 80; 3, 27, 60, 78;
        13, 39, 53, 69; 2, 20, 46, 68; 4, 30, 48, 74; 19, 21, 63, 64;
        19, 29, 66, 84; 3, 21, 47, 69; 4, 40, 53, 84; 10, 28, 54, 72;
        8, 34, 48, 73; 15, 33, 47, 79; 14, 32, 46, 78;
        15, 34, 57, 71; 6, 24, 50, 61; 22, 42, 59, 76; 11, 25, 65, 82;
        13, 36, 56, 82; 10, 24, 64, 83; 5, 41, 52, 85; 7, 30, 50, 81;
        8, 32, 58, 76; 16, 42, 66, 80; 18, 20, 62, 65
    ];

    % GF Element Values
    hElementsRaw = [
        30, 24, 1, 44; 51, 60, 35, 13; 6, 1, 45, 15; 24, 1, 44, 53; 1, 44, 53, 24;
        13, 18, 60, 1; 44, 53, 24, 35; 15, 35, 46, 56; 44, 30, 24, 1; 33, 42, 14, 5;
        45, 15, 6, 1; 24, 1, 44, 30; 18, 15, 32, 61; 45, 15, 6, 1; 44, 30, 24, 1;
        61, 47, 20, 8; 45, 15, 6, 1; 39, 36, 34, 33; 53, 24, 1, 44; 15, 6, 1, 45;
        34, 3, 55, 9; 1, 44, 30, 24; 40, 32, 61, 18; 1, 6, 1, 45; 15, 45, 15, 6; 
        34, 33, 45, 36; 53, 24, 1, 44; 24, 1, 44, 53; 44, 35, 31, 50; 1, 44, 53, 24;
        30, 24, 1, 44; 44, 35, 61, 50; 6, 1, 45, 15; 53, 24, 1, 44; 30, 24, 1, 44;
         1, 44, 53, 24; 55, 9, 34, 3; 15, 6, 1, 45; 37, 32, 52, 47; 12, 25, 36, 14;
        24, 1, 44, 30; 2, 50, 22, 14; 15, 6, 1, 45; 1, 44, 53, 24
    ];

    %% ================= 2. Matrix Reconstruction =================
    % Convert 0-based indices to 1-based (MATLAB standard)
    hIndices = hIndicesRaw + 1;
    
    % Initialize 44x88 Parity Check Matrix H
    hMatrix = zeros(44, 88);
    
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
    
    %% ================= 3. Generator Matrix Construction =================
    % H = [H1 | H2]
    h1 = hMatrixGf(:, 1:44);    % Information part connection
    h2 = hMatrixGf(:, 45:88);   % Parity part connection (Square, Invertible)
    
    % Compute Parity Generator Part: G2 = (H2^-1 * H1)^T
    g2 = (h2 \ h1).'; 
    
    % Construct Systematic Generator Matrix G = [I | G2] implicitly
    
    %% ================= 4. Encoding =================
    infoSeqGf = gf(infoSymbols, gfBits);
    
    % Calculate Parity Symbols
    paritySeqGf = infoSeqGf * g2;
    
    % Concatenate to form full codeword: [Info, Parity]
    codewordGf = [infoSeqGf, paritySeqGf];
    
    %% ================= 5. Binary Conversion (Optimized) =================
    % Extract numeric values from GF object
    numericCodeword = double(codewordGf.x); % [1 x 88]
    
    % Vectorized conversion from Decimal to Binary Matrix
    % 1. Transpose to column vector [88 x 1] for dec2bin
    % 2. dec2bin produces char matrix [88 x 6]
    % 3. Subtracting '0' converts char '0'/'1' to double 0/1
    binaryCodeword = dec2bin(numericCodeword.', gfBits) - '0';
    
    % Output format: [88 x 6] (Rows=Symbols, Cols=Bits)
    
end