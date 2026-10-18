function [decodedCodeword, realIter] = ldpcDecode(llr, hMatrix, settings)
%LDPCDECODE Dispatch GPS L1C CNAV-2 LDPC decoding by configured algorithm.
%   settings.decoderType supports: 'MS', 'BP', and 'NeuralMS'.

decoderType = upper(string(getSetting(settings, 'decoderType', 'MS')));

switch decoderType
    case {"MS", "MINSUM", "MIN-SUM", "OMS", "NMS"}
        [decodedCodeword, realIter] = msDecode(llr, hMatrix, settings);

    case {"BP", "SPA", "SUMPRODUCT", "SUM-PRODUCT"}
        [decodedCodeword, realIter] = bpDecode(llr, hMatrix, settings);

    case {"NEURALMS", "NEURAL_MS", "NEURAL-MIN-SUM", "NEURALMIN-SUM"}
        neuralParams = loadNeuralParams(settings);
        [decodedCodeword, realIter] = neuralmsDecode(llr, hMatrix, settings, neuralParams);

    otherwise
        error('ldpcDecode:UnknownDecoder', ...
            'Unsupported LDPC decoderType "%s". Use MS, BP, or NeuralMS.', ...
            getSetting(settings, 'decoderType', ''));
end
end

function neuralParams = loadNeuralParams(settings)
persistent weightCache
if isempty(weightCache)
    weightCache = containers.Map();
end

messageType = char(getSetting(settings, 'messageType', 'L1C_2'));
if isfield(settings, 'neuralWeightsFile') && ~isempty(settings.neuralWeightsFile)
    weightsFile = settings.neuralWeightsFile;
else
    thisDir = fileparts(mfilename('fullpath'));
    weightsFile = fullfile(thisDir, sprintf('NMS_Weights_%s_Final.mat', messageType));
end

cacheKey = char(weightsFile);
if isKey(weightCache, cacheKey)
    neuralParams = weightCache(cacheKey);
    return;
end

weightData = load(weightsFile, 'neuralParams');
if ~isfield(weightData, 'neuralParams')
    error('ldpcDecode:MissingNeuralParams', ...
        'NeuralMS weights file does not contain neuralParams: %s', weightsFile);
end

neuralParams = weightData.neuralParams;
weightCache(cacheKey) = neuralParams;
end

function value = getSetting(settings, fieldName, defaultValue)
if isstruct(settings) && isfield(settings, fieldName)
    value = settings.(fieldName);
else
    value = defaultValue;
end
end
