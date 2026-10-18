function codeword = encodingL1C_2(infoBits)
% =========================================================================
% FUNCTION: encodingL1C_2
% DESCRIPTION:
%   Performs LDPC encoding for GPS L1C Subframe 2 (CNAV-2).
%   Algorithm: Richardson-Urbanke (RU) method.
%
% INPUTS:
%   infoBits : [600 x 1] Information bits (column vector).
%
% OUTPUTS:
%   codeword : [1200 x 1] Encoded codeword [Systematic; Parity1; Parity2].
% =========================================================================

    %% Initialization & Input Validation===================================
    % Ensure input is a column vector
    infoBits = infoBits(:);
    
    % Validate input length (L1C Subframe 2 has 600 info bits)
    expectedLength = 600;
    if length(infoBits) ~= expectedLength
        error('encodingL1C_2: Input length must be %d.', expectedLength);
    end

    % Load Coordinate Tables
    % Assumes 'gpsCnav2LdpcTables.m' puts H_CNV2_SF2_* into workspace
    gpsCnav2LdpcTables; 
    
    %% Matrix Dimensions Setup (GPS L1C Subframe 2)========================
    numCols = 600;  % k (Information length)
    numRows = 600;  % m = n - k (Parity length)
    gap     = 1;    % g (Gap parameter for RU method)
    
    dimM1 = numRows - gap; % 599 (m - g)
    dimG  = gap;           % 1   (g)
    
    %% 3. Construct Sparse Sub-matrices
    % The H matrix is structured as:
    % [ A  B  T ]
    % [ C  D  E ]
    
    % A: [ (m-g) x k ] -> [599 x 600]
    matrixA = coordsToSparse(H_CNV2_SF2_A, dimM1, numCols);
    
    % B: [ (m-g) x g ] -> [599 x 1]
    matrixB = coordsToSparse(H_CNV2_SF2_B, dimM1, dimG);
    
    % C: [ g x k ] -> [1 x 600]
    matrixC = coordsToSparse(H_CNV2_SF2_C, dimG, numCols);
    
    % D: [ g x g ] -> [1 x 1]
    matrixD = coordsToSparse(H_CNV2_SF2_D, dimG, dimG);
    
    % E: [ g x (m-g) ] -> [1 x 599]
    matrixE = coordsToSparse(H_CNV2_SF2_E, dimG, dimM1);
    
    % T: [ (m-g) x (m-g) ] -> [599 x 599] Lower Triangular
    matrixT = coordsToSparse(H_CNV2_SF2_T, dimM1, dimM1);
    
    %% 4. Richardson-Urbanke Encoding Steps (GF(2))
    
    % --- Step 4.1: Compute Phi ---
    % Phi = -E * T^(-1) * B + D
    
    % Calculate T^(-1) * B using forward substitution
    invTB = matrixT \ matrixB; 
    
    % Calculate Phi (In GF(2), -x = x)
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
    phiFull = full(phiMatrix);
    phiGf   = gf(phiFull, 1);       % GF(2)
    invPhiGf = inv(phiGf);          
    invPhi   = double(invPhiGf.x);  
    
    % Compute p1
    partialSyndrome = tempMatrix * infoBits;
    parityBits1 = invPhi * partialSyndrome;
    parityBits1 = mod(parityBits1, 2);
    
    %% 5. Compute Parity Part 2 (p2)
    % p2 = -T^(-1) * (A * s + B * p1)
    
    rhsVector = matrixA * infoBits + matrixB * parityBits1;
    parityBits2 = -matrixT \ rhsVector;
    parityBits2 = mod(parityBits2, 2);
    
    %% 6. Assemble Final Codeword
    % Format: [Systematic Bits; Parity 1; Parity 2]
    codeword = [infoBits; parityBits1; parityBits2];
    
    % Final check to ensure binary
    codeword = mod(codeword, 2);

end