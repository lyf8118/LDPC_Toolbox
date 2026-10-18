function neuralParams = loadB2bNeuralParams(settings, decoderType)
%LOADB2BNEURALPARAMS Load cached NEMS/SNEMS inference weights.

persistent weightCache
if isempty(weightCache)
    weightCache = containers.Map();
end

decoderType = upper(char(decoderType));
thisDir = fileparts(mfilename('fullpath'));

switch decoderType
    case 'NEMS'
        explicitField = 'nemsWeightsFile';
        defaultFile = fullfile(thisDir, 'nems_B2b_weights.mat');
    case 'SNEMS'
        explicitField = 'snemsWeightsFile';
        defaultFile = fullfile(thisDir, 'snems_B2b_weights.mat');
    otherwise
        error('loadB2bNeuralParams:UnknownDecoder', ...
            'Unsupported neural decoder "%s".', decoderType);
end

if isfield(settings, explicitField) && ~isempty(settings.(explicitField))
    weightsFile = settings.(explicitField);
elseif isfield(settings, 'neuralWeightsFile') && ~isempty(settings.neuralWeightsFile)
    weightsFile = settings.neuralWeightsFile;
else
    weightsFile = defaultFile;
end

cacheKey = [decoderType ':' char(weightsFile)];
if isKey(weightCache, cacheKey)
    neuralParams = weightCache(cacheKey);
    return;
end

if ~exist(weightsFile, 'file')
    warning('loadB2bNeuralParams:MissingWeights', ...
        'Weight file "%s" not found. Using unit weights for %s.', weightsFile, decoderType);
    neuralParams = defaultNeuralParams(settings, decoderType);
    weightCache(cacheKey) = neuralParams;
    return;
end

loadedData = load(weightsFile);
if ~isfield(loadedData, 'c2vWeights') || ~isfield(loadedData, 'vnWeights')
    error('loadB2bNeuralParams:InvalidWeights', ...
        'Weight file must contain c2vWeights and vnWeights: %s', weightsFile);
end

neuralParams.c2vWeights = single(loadedData.c2vWeights);
neuralParams.vnWeights = single(loadedData.vnWeights);
neuralParams.isTrainMode = false;
weightCache(cacheKey) = neuralParams;
end

function neuralParams = defaultNeuralParams(settings, decoderType)
settings = prepareB2bLdpcSettings(settings);
maxIterations = settings.maxIterations;
switch decoderType
    case 'NEMS'
        graph = getB2bLdpcGraph(settings);
        neuralParams.c2vWeights = ones(graph.numEdges, 1, maxIterations, 'single');
    case 'SNEMS'
        neuralParams.c2vWeights = ones(1, 1, maxIterations, 'single');
end
neuralParams.vnWeights = ones(1, 1, maxIterations, 'single');
neuralParams.isTrainMode = false;
end
