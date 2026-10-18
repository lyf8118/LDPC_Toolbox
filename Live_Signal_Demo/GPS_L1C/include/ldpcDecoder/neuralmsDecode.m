function [decodedCodeword, realIter] = neuralmsDecode(llr, hMatrix, settings, neuralParams)
%NEURALMSDECODE Neural/weighted Min-Sum decoder for GPS L1C CNAV-2 LDPC.
%   The parity-check matrix is supplied by the receiver (H2/H3). The
%   learned weights are indexed by check-node degree and iteration.

if nargin < 4
    error('neuralmsDecode:MissingWeights', ...
        'neuralmsDecode requires neuralParams.weights.');
end

llr = llr(:);
hMatrix = sparse(logical(hMatrix));
[numRows, numCols] = size(hMatrix);

if length(llr) ~= numCols
    error('neuralmsDecode:InputSize', ...
        'LLR length (%d) does not match LDPC matrix columns (%d).', ...
        length(llr), numCols);
end

if ~isfield(neuralParams, 'weights')
    error('neuralmsDecode:MissingWeights', ...
        'neuralParams must contain a weights field.');
end

weights = neuralParams.weights;
maxIterations = min(getSetting(settings, 'maxIterations', 50), size(weights, 2));

persistent graphCache
if isempty(graphCache)
    graphCache = containers.Map();
end

messageType = getSetting(settings, 'messageType', 'CNAV2');
cacheKey = sprintf('%s_%dx%d_%d', messageType, numRows, numCols, nnz(hMatrix));

if isKey(graphCache, cacheKey)
    graph = graphCache(cacheKey);
else
    [rowIndices, colIndices] = find(hMatrix);
    numEdges = length(rowIndices);
    graph.hMatrix = hMatrix;
    graph.colIndices = colIndices;
    graph.cnConnections = accumarray(rowIndices, (1:numEdges).', ...
        [numRows 1], @(y){y});
    graph.numEdges = numEdges;
    graphCache(cacheKey) = graph;
end

colIndices = graph.colIndices;
cnConnections = graph.cnConnections;
numEdges = graph.numEdges;
hMatrix = graph.hMatrix;

if maxIterations == 0
    decodedCodeword = double(llr < 0);
    realIter = 0;
    return;
end

chkToVarMsg = zeros(numEdges, 1);
varToChkMsg = llr(colIndices);
decodedCodeword = double(llr < 0);
realIter = maxIterations;

for iter = 1:maxIterations
    for cn = 1:numRows
        edgeIndices = cnConnections{cn};
        degree = length(edgeIndices);

        if degree < 2
            chkToVarMsg(edgeIndices) = 0;
            continue;
        end

        qMessages = varToChkMsg(edgeIndices);

        signVec = sign(qMessages);
        signVec(signVec == 0) = 1;
        signProduct = prod(signVec);

        absQ = abs(qMessages);
        [min1, minIdx] = min(absQ);
        absQ(minIdx) = inf;
        min2 = min(absQ);

        magnitudes = min1 * ones(degree, 1);
        magnitudes(minIdx) = min2;
        rawMsg = (signProduct .* signVec) .* magnitudes;

        weightRow = min(degree, size(weights, 1));
        chkToVarMsg(edgeIndices) = weights(weightRow, iter) * rawMsg;
    end

    sumChkToVar = accumarray(colIndices, chkToVarMsg, [numCols 1], @sum, 0);
    posteriorLlr = llr + sumChkToVar;
    decodedCodeword = double(posteriorLlr < 0);

    if ~any(mod(hMatrix * decodedCodeword, 2))
        realIter = iter;
        return;
    end

    varToChkMsg = posteriorLlr(colIndices) - chkToVarMsg;
end
end

function value = getSetting(settings, fieldName, defaultValue)
if isstruct(settings) && isfield(settings, fieldName)
    value = settings.(fieldName);
else
    value = defaultValue;
end
end
