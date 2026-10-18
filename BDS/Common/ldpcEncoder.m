function [ldpcInMsg, originalData] = ldpcEncoder(settings)
% =========================================================================
% FUNCTION: ldpcEncoder
% DESCRIPTION:
%   Generates random information bits, performs LDPC encoding based on the
%   specified GNSS message type, and applies BPSK modulation.
% =========================================================================

    %%  Information Bit Generation ========================================
    % Generate random binary sequence (0/1) as ground truth
    totalBits    = settings.symbolsPerFrame * settings.bitsPerSymbol;
    originalData = double(rand(1, totalBits) > 0.5);

    % Map binary bits to decimal Galois Field (GF) symbols
    numGroups     = length(originalData) / settings.bitsPerSymbol;      
    decimalValues = zeros(1, numGroups);
    
    for i = 1:numGroups
        % Extract bits for current symbol and convert to decimal
        currentBits = originalData((i-1)*settings.bitsPerSymbol + 1 : i*settings.bitsPerSymbol);
        decimalValues(i) = bi2de(currentBits, 'left-msb');
    end

    %%  LDPC Encoding =====================================================
    % Dispatch to specific encoding function based on signal configuration
    switch settings.messageType
        case 'B1C_2'
            encodedMatrix = encodingB1C_2(decimalValues);
        case 'B1C_3'   
            encodedMatrix = encodingB1C_3(decimalValues);
        case 'B2a'
            encodedMatrix = encodingB2a(decimalValues);
        case 'B2b'
            encodedMatrix = encodingB2b(decimalValues);
        otherwise
            error('ldpcEncoder: Unknown messageType "%s"', settings.messageType);
    end

    %% BPSK Modulation ====================================================
    % Flatten the GF matrix to a binary stream and modulate (0 -> +1, 1 -> -1)
    binaryCodeword = reshape(encodedMatrix.', 1, []);     
    ldpcInMsg      = 1 - 2 * binaryCodeword;                 

end