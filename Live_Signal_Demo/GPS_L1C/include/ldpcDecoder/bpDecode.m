function [decodedCodeword, realIter] = bpDecode(llr, hMatrix, settings)
%BPDECODE Sum-Product BP decoder for GPS L1C CNAV-2 LDPC codewords.
%   This version accepts the receiver's H2/H3 parity-check matrices directly.

if nargin == 2
    settings = hMatrix;
    if ~isfield(settings, 'hMatrix')
        error('bpDecode:MissingHMatrix', ...
            'Call bpDecode with hMatrix or provide settings.hMatrix.');
    end
    hMatrix = settings.hMatrix;
end

llr = llr(:);
hMatrix = sparse(logical(hMatrix));
[numRows, numCols] = size(hMatrix);

if length(llr) ~= numCols
    error('bpDecode:InputSize', ...
        'LLR length (%d) does not match LDPC matrix columns (%d).', ...
        length(llr), numCols);
end

maxIterations = getSetting(settings, 'maxIterations', 50);

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

        forwardSum = zeros(degree, 1);
        forwardSum(1) = qMessages(1);
        for k = 2:degree
            forwardSum(k) = boxPlus(forwardSum(k - 1), qMessages(k));
        end

        backwardSum = zeros(degree, 1);
        backwardSum(degree) = qMessages(degree);
        for k = (degree - 1):-1:1
            backwardSum(k) = boxPlus(qMessages(k), backwardSum(k + 1));
        end

        for k = 1:degree
            edgeIdx = edgeIndices(k);
            if k == 1
                chkToVarMsg(edgeIdx) = backwardSum(2);
            elseif k == degree
                chkToVarMsg(edgeIdx) = forwardSum(degree - 1);
            else
                chkToVarMsg(edgeIdx) = boxPlus(forwardSum(k - 1), backwardSum(k + 1));
            end
        end
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
