function codeword = encodingL1C_3(infoBits)
% =========================================================================
% FUNCTION: encodingL1C_3
% DESCRIPTION:
%   Performs LDPC encoding for GPS L1C Subframe 3 (CNAV-2).
%   Algorithm: Richardson-Urbanke (RU) method.
%
% INPUTS:
%   infoBits : [274 x 1] Information bits (column vector).
%
% OUTPUTS:
%   codeword : [548 x 1] Encoded codeword [Systematic; Parity1; Parity2].
% =========================================================================

    %% Initialization & Input Validation ==================================
    % Ensure input is a column vector
    infoBits = infoBits(:);
    
    % Validate input length (L1C Subframe 3 has 274 info bits)
    expectedLength = 274;
    if length(infoBits) ~= expectedLength
        error('encodingL1C_3: Input length must be %d.', expectedLength);
    end
    
    % Load Coordinate Tables
    % Assumes 'gpsCnav2LdpcTables.m' puts H_CNV2_SF3_* into workspace
    % Make sure your table file defines: H_CNV2_SF3_A, H_CNV2_SF3_B, etc.
    gpsCnav2LdpcTables; 
    
    %% Matrix Dimensions Setup (GPS L1C Subframe 3) =======================
    numCols = 274;  % k (Information length)
    numRows = 274;  % m = n - k (Parity length)
    gap     = 1;    % g (Gap parameter for RU method)
    
    dimM1 = numRows - gap; % 273 (m - g)
    dimG  = gap;           % 1   (g)
    
    %% 3. Construct Sparse Sub-matrices
    % The H matrix is structured as:
    % [ A  B  T ]
    % [ C  D  E ]
    
    % A: [ (m-g) x k ] -> [273 x 274]
    matrixA = coordsToSparse(H_CNV2_SF3_A, dimM1, numCols);
    
    % B: [ (m-g) x g ] -> [273 x 1]
    matrixB = coordsToSparse(H_CNV2_SF3_B, dimM1, dimG);
    
    % C: [ g x k ] -> [1 x 274]
    matrixC = coordsToSparse(H_CNV2_SF3_C, dimG, numCols);
    
    % D: [ g x g ] -> [1 x 1]
    matrixD = coordsToSparse(H_CNV2_SF3_D, dimG, dimG);
    
    % E: [ g x (m-g) ] -> [1 x 273]
    matrixE = coordsToSparse(H_CNV2_SF3_E, dimG, dimM1);
    
    % T: [ (m-g) x (m-g) ] -> [273 x 273] Lower Triangular
    matrixT = coordsToSparse(H_CNV2_SF3_T, dimM1, dimM1);
    
    %% 4. Richardson-Urbanke Encoding Steps (GF(2))
    % Note: The RU logic below is identical to SF2, just applying to 
    % matrices of different dimensions.
    
    % --- Step 4.1: Compute Phi ---
    % Phi = -E * T^(-1) * B + D
    
    % Calculate T^(-1) * B using forward substitution
    % Since T is lower triangular, backslash (\) is efficient here.
    invTB = matrixT \ matrixB; 
    
    % Calculate Phi (In GF(2), -x = x, subtraction is addition)
    phiMatrix = -matrixE * invTB + matrixD;
    phiMatrix = mod(phiMatrix, 2);
    
    % --- Step 4.2: Compute Parity Part 1 (p1) ---
    % p1 = -Phi^(-1) * (-E * T^(-1) * A + C) * s
    
    % Calculate T^(-1) * A
    invTA = matrixT \ matrixA;
    
    % Calculate intermediate term: (-E * T^(-1) * A + C)
    tempMatrix = -matrixE * invTA + matrixC;
    tempMatrix = mod(tempMatrix, 2);
    
    % Calculate Inverse of Phi in GF(2)
    % For gap=1, Phi is a scalar (1x1). If Phi=1, inv=1. If Phi=0, singular.
    phiFull = full(phiMatrix);
    phiGf   = gf(phiFull, 1);       % GF(2) context
    invPhiGf = inv(phiGf);          
    invPhi   = double(invPhiGf.x);  
    
    % Compute p1
    partialSyndrome = tempMatrix * infoBits;
    parityBits1 = invPhi * partialSyndrome;
    parityBits1 = mod(parityBits1, 2);
    
    %% 5. Compute Parity Part 2 (p2)
    % p2 = -T^(-1) * (A * s + B * p1)
    rhsVector = matrixA * infoBits + matrixB * parityBits1;
    
    % Solve for p2 using forward substitution (T is lower triangular)
    parityBits2 = -matrixT \ rhsVector;
    parityBits2 = mod(parityBits2, 2);
    
    %% 6. Assemble Final Codeword
    % Format: [Systematic Bits; Parity 1; Parity 2]
    codeword = [infoBits; parityBits1; parityBits2];
    
    % Final check to ensure binary
    codeword = mod(codeword, 2);
end
