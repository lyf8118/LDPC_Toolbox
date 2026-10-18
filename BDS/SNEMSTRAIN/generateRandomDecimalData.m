function [binaryCodeword, decimalCodeword] = generateRandomDecimalData(settings)
% =========================================================================
% FUNCTION: generateRandomDecimalData
% DESCRIPTION:
%   Generates random information symbols, encodes them using the specific 
%   encoder defined in 'settings', and returns the data in Binary, 
%   Decimal-Codeword, and Decimal-Source formats.
%
% INPUTS:
%   settings        : Configuration structure (needs messageType, symbolsPerFrame, etc.)
%
% OUTPUTS:
%   binaryCodeword  : [N x gfBits] Encoded binary matrix (for Channel/Modulation).
%   decimalCodeword : [1 x N] Encoded decimal symbols (Ground Truth Labels).
%   infoSymbols     : [1 x K] Original source symbols (Source Info).
% =========================================================================

    %%  Generate Random Source Data========================================
    % Generate random integer symbols in range [0, 63] directly
    % settings.symbolsPerFrame defines K (e.g., 48, 81, 100, 44)
    infoSymbols = randi([0, settings.gfSize - 1], 1, settings.symbolsPerFrame);

    %%  Select Encoder & Encode============================================
    switch settings.messageType
        case 'B1C_2'
            % K=100, N=200
            [binaryCodeword, decimalCodeword] = encodingB1C_2(infoSymbols);

            
        case 'B1C_3'
            % K=44, N=88
            [binaryCodeword, decimalCodeword] = encodingB1C_3(infoSymbols);
            
            
        case 'B2a'
            % K=48, N=96
            [binaryCodeword, decimalCodeword] = encodingB2a(infoSymbols);
            
        case 'B2b'
            % K=81, N=162
            [binaryCodeword, decimalCodeword] = encodingB2b(infoSymbols);
          
        otherwise
            error('generateRandomDecimalData: Unknown messageType "%s"', settings.messageType);
    end
    

end
