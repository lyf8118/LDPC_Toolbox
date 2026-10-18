function gfMulTable = getGfTable()
% =========================================================================
% FUNCTION: getGfTable
% DESCRIPTION:
%   Generates the pre-computed Multiplication Table for the Galois Field 
%   GF(2^6) = GF(64).
%
%   Instead of performing polynomial multiplication and modulo reduction 
%   at runtime, this function builds a Look-Up Table (LUT) using the 
%   logarithm/exponent property of finite fields:
%       A * B = alpha^(log_alpha(A) + log_alpha(B))
%
%   It relies on two hardcoded arrays:
%       - gfExpTable: Exponential table (alpha^k -> integer)
%       - gfLogTable: Logarithm table (integer -> k)
%
% INPUTS:
%   None (Parameters gfBits=6 and gfSize=64 are internal constants).
%
% OUTPUTS:
%   gfMulTable : [64 x 64] uint8 Matrix where gfMulTable(i+1, j+1) contains 
%                the product of GF symbols 'i' and 'j'.
% =========================================================================

    % Define Field Constants
    gfBits = 6;           % Bits per symbol
    gfSize = 2^gfBits;    % Field size (64 elements)

    % --- 1. Define Look-Up Tables (Hardcoded for GF(64)) ---
    
    % Exponential Table: Maps power k to element alpha^k
    % Index i corresponds to power (i-1). Example: gfExpTable(2) is alpha^1
    gfExpTable = [1, 2, 4, 8, 16, 32, 3, 6, 12, 24, 48, 35, 5, 10, 20, 40,...
        19, 38, 15, 30, 60, 59, 53, 41, 17, 34, 7, 14, 28, 56, 51, 37,...
        9, 18, 36, 11, 22, 44, 27, 54, 47, 29, 58, 55, 45, 25, 50, 39,...
        13, 26, 52, 43, 21, 42, 23, 46, 31, 62, 63, 61, 57, 49, 33];
        
    % Logarithm Table: Maps element x to power k such that x = alpha^k
    % Index i corresponds to integer value (i-1).
    % Note: Log(0) is undefined, represented as 0 here (handled by logic).
    gfLogTable = [0, 0, 1, 6, 2, 12, 7, 26, 3, 32, 13, 35, 8, 48, 27, 18,...
        4, 24, 33, 16, 14, 52, 36, 54, 9, 45, 49, 38, 28, 41, 19, 56,...
        5, 62, 25, 11, 34, 31, 17, 47, 15, 23, 53, 51, 37, 44, 55, 40,...
        10, 61, 46, 30, 50, 22, 39, 43, 29, 60, 42, 21, 20, 59, 57, 58];

    % --- 2. Generate Multiplication Matrix ---
    % Initialize zero matrix (handles 0 * x = 0 automatically)
    gfMulTable = zeros(gfSize, gfSize, 'uint8');

    % Iterate through non-zero elements (1 to 63)
    % Note: Indices in MATLAB are 1-based, so element 'x' is at index 'x+1'
    for i = 1 : gfSize-1
        for j = 1 : gfSize-1
            % Calculate sum of logarithms modulo (Q-1)
            % Formula: log(A*B) = (log(A) + log(B)) mod (2^N - 1)
            % We add 1 to indices to access the MATLAB arrays correctly.
            powerSum = gfLogTable(i+1) + gfLogTable(j+1);
            powerIdx = mod(powerSum, gfSize-1);
            
            % Map back to integer using exponential table
            % Add 1 to index because gfExpTable is 1-based
            gfMulTable(i+1, j+1) = gfExpTable(powerIdx + 1);
        end
    end
end