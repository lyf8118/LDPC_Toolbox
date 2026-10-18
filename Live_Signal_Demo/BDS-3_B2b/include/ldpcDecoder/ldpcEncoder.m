function [ldpcInMsg, originalData, encodedMatrix] = ldpcEncoder(settings, originalData)
%LDPCENCODER Generate or encode a BDS B2b LDPC codeword and BPSK symbols.

settings = prepareB2bLdpcSettings(settings);

if nargin < 2 || isempty(originalData)
    totalBits = settings.symbolsPerFrame * settings.bitsPerSymbol;
    originalData = double(rand(1, totalBits) > 0.5);
else
    originalData = double(originalData(:).');
end

if mod(numel(originalData), settings.bitsPerSymbol) ~= 0
    error('ldpcEncoder:InputSize', ...
        'Input bit count must be a multiple of settings.bitsPerSymbol.');
end

numSymbols = numel(originalData) / settings.bitsPerSymbol;
decimalValues = zeros(1, numSymbols);
for idx = 1:numSymbols
    bitSlice = originalData((idx - 1) * settings.bitsPerSymbol + 1:idx * settings.bitsPerSymbol);
    decimalValues(idx) = bin2dec(char(bitSlice + '0'));
end

switch char(settings.messageType)
    case 'B2b'
        encodedMatrix = encoding(decimalValues);
    otherwise
        error('ldpcEncoder:UnknownMessageType', ...
            'This receiver only includes the B2b LDPC encoder.');
end

binaryCodeword = reshape(encodedMatrix.', 1, []);
ldpcInMsg = 1 - 2 * binaryCodeword;
end
