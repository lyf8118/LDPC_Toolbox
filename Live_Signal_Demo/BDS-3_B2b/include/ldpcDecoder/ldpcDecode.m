function [decodedCodeword, realIter] = ldpcDecode(normalizedPromptI, sigmaSquaredNorm, settings)
%LDPCDECODE Dispatch BDS B2b non-binary LDPC decoding by settings.decoderType.
%   Supported decoderType values:
%     EMS, FFT-QSPA, NEMS, SNEMS.

if nargin < 3
    error('ldpcDecode:InputCount', ...
        'ldpcDecode requires normalizedPromptI, sigmaSquaredNorm, and settings.');
end

settings = prepareB2bLdpcSettings(settings);
decoderType = upper(string(ldpcGetSetting(settings, 'decoderType', 'EMS')));

switch decoderType
    case {"EMS", "OEMS", "OFFSET-EMS", "NORMALIZED-EMS"}
        llrMatrix = initLlr(normalizedPromptI, sigmaSquaredNorm, settings);
        [decodedCodeword, realIter] = emsDecode(llrMatrix, settings);

    case {"FFT-QSPA", "FFTQSPA", "QSPA", "FFT_QSPA"}
        symbolProbabilities = initQspaProbabilities(normalizedPromptI, sigmaSquaredNorm, settings);
        [decodedCodeword, realIter] = fftQspaDecode(symbolProbabilities, settings);

    case {"NEMS", "NEURAL-EMS", "NEMS-EDGE"}
        llrMatrix = initLlr(normalizedPromptI, sigmaSquaredNorm, settings);
        neuralParams = loadB2bNeuralParams(settings, 'NEMS');
        [decodedCodeword, realIter] = nemsDecode(llrMatrix, settings, neuralParams);

    case {"SNEMS", "SHARED-NEMS", "SHARED-EMS"}
        llrMatrix = initLlr(normalizedPromptI, sigmaSquaredNorm, settings);
        neuralParams = loadB2bNeuralParams(settings, 'SNEMS');
        [decodedCodeword, realIter] = snemsDecode(llrMatrix, settings, neuralParams);

    otherwise
        error('ldpcDecode:UnknownDecoder', ...
            'Unsupported B2b LDPC decoderType "%s". Use EMS, FFT-QSPA, NEMS, or SNEMS.', ...
            char(decoderType));
end

decodedCodeword = double(decodedCodeword(:).');
end
