function [ldpcInMsg, originalData] = ldpcEncoder(settings)
% =========================================================================
% FUNCTION: ldpcEncoder
% DESCRIPTION:
%   Generates random information bits, performs LDPC encoding based on the
%   specified GNSS message type, and applies BPSK modulation.
%   Supports GPS L1C Subframe 2 and Subframe 3.
% =========================================================================

    %%  Information Bit Generation ========================================
    % Generate random binary sequence (0/1) based on settings.symbolsPerFrame
    % For L1C_SF2: generates 600 bits
    % For L1C_SF3: generates 274 bits
    totalBits    = settings.symbolsPerFrame * settings.bitsPerSymbol;
    originalData = double(rand(1, totalBits) > 0.5);

    %%  LDPC Encoding =====================================================
    % Dispatch to specific encoding function based on signal configuration
    % Note: Since bitsPerSymbol=1 (Binary), we pass originalData directly.
    switch settings.messageType
        case 'L1C_2'
            % Input: 1x600 bits -> Output: 1x1200 bits
            encoded = encodingL1C_2(originalData);

        case 'L1C_3'   
            % Input: 1x274 bits -> Output: 1x548 bits
            encoded = encodingL1C_3(originalData);

        otherwise
            error('ldpcEncoder: Unknown messageType "%s"', settings.messageType);
    end

    %% BPSK Modulation ====================================================
    % Flatten the codeword to a binary stream and modulate (0 -> +1, 1 -> -1)
    % reshape ensures it is a 1-row vector regardless of encoding output shape
    binaryCodeword = reshape(encoded, 1, []);     
    ldpcInMsg      = 1 - 2 * binaryCodeword;                 
end