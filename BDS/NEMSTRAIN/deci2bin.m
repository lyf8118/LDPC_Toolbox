function binaryVector = deci2bin(decimalValue, numBits)
% =========================================================================
% FUNCTION: deci2bin
% DESCRIPTION:
%   Converts a decimal integer into a numeric binary array (vector of bits).
%   Example: deci2Bin(5, 4) -> [0, 1, 0, 1] (double type)
%
% INPUTS:
%   decimalValue : Decimal integer to convert.
%   numBits      : Number of bits (length of the output vector).
%
% OUTPUTS:
%   binaryVector : [1 x numBits] Numeric array representing the binary sequence.
% =========================================================================

    % 1. Convert decimal to binary character string
    % dec2bin returns a char array, e.g., '101'
    binCharStr = dec2bin(decimalValue, numBits);
    
    % 2. Convert character string to numeric vector (Vectorized)
    % Subtracting the character '0' converts ASCII '0'/'1' to double 0/1.
    % This is significantly faster than using str2double in a loop.
    binaryVector = binCharStr - '0';
    
end