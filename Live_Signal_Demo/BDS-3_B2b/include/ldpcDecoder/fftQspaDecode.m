function [decodedCodeword, realIter] = fftQspaDecode(symbolProbabilities, settings)
%FFTQSPADECODE FFT-QSPA decoder for BDS B2b non-binary LDPC.

settings = prepareB2bLdpcSettings(settings);
graph = getB2bLdpcGraph(settings);

probabilities = double(symbolProbabilities);
probabilities = max(probabilities, realmin);
probabilities = probabilities ./ sum(probabilities, 2);

intrinsicLogProb = log(probabilities);
[~, maxIndices] = max(intrinsicLogProb, [], 2);
decodedCodeword = double(maxIndices - 1).';

varToCheckMsg = zeros(graph.numEdges, settings.gfSize);
checkToVarMsg = zeros(graph.numEdges, settings.gfSize);

invEdgeWeights = zeros(size(graph.edgeWeights));
for edgeIdx = 1:graph.numEdges
    edgeWeight = graph.edgeWeights(edgeIdx);
    invEdgeWeights(edgeIdx) = gfInverse(edgeWeight, settings.gfMulTable);
    varToCheckMsg(edgeIdx, :) = permuteLlr( ...
        intrinsicLogProb(graph.colIndices(edgeIdx), :), edgeWeight, settings.gfMulTable);
end

realIter = settings.maxIterations;
if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
    realIter = 0;
    return;
end

for iter = 1:settings.maxIterations
    for varIdx = 1:settings.colH
        edgeList = graph.vnConnections{varIdx};
        posterior = intrinsicLogProb(varIdx, :) + sum(checkToVarMsg(edgeList, :), 1);
        [~, maxIdx] = max(posterior);
        decodedCodeword(varIdx) = maxIdx - 1;

        for edgePos = 1:numel(edgeList)
            edgeIdx = edgeList(edgePos);
            extrinsic = posterior - checkToVarMsg(edgeIdx, :);
            varToCheckMsg(edgeIdx, :) = permuteLlr(extrinsic, ...
                graph.edgeWeights(edgeIdx), settings.gfMulTable);
        end
    end

    if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
        realIter = iter;
        return;
    end

    for checkIdx = 1:settings.rowH
        edgeList = graph.cnConnections{checkIdx};
        incomingLog = varToCheckMsg(edgeList, :);
        incomingLog = incomingLog - max(incomingLog, [], 2);
        incomingProb = exp(incomingLog);
        incomingProb = incomingProb ./ sum(incomingProb, 2);

        spectrum = hadamardTransformRows(incomingProb);
        totalProduct = prod(spectrum, 1);
        outgoingSpectrum = zeros(size(spectrum));

        for edgePos = 1:numel(edgeList)
            denom = spectrum(edgePos, :);
            validMask = abs(denom) > 1e-15;
            outgoingSpectrum(edgePos, validMask) = totalProduct(validMask) ./ denom(validMask);
        end

        outgoingProb = inverseHadamardTransformRows(outgoingSpectrum);
        outgoingProb = max(real(outgoingProb), realmin);
        outgoingLog = log(outgoingProb);

        for edgePos = 1:numel(edgeList)
            edgeIdx = edgeList(edgePos);
            checkToVarMsg(edgeIdx, :) = permuteLlr(outgoingLog(edgePos, :), ...
                invEdgeWeights(edgeIdx), settings.gfMulTable);
        end
    end
end
end

function y = hadamardTransformRows(x)
y = x;
n = size(y, 2);
step = 1;
while step < n
    for idx = 1:(2 * step):n
        left = y(:, idx:idx + step - 1);
        right = y(:, idx + step:idx + 2 * step - 1);
        y(:, idx:idx + step - 1) = left + right;
        y(:, idx + step:idx + 2 * step - 1) = left - right;
    end
    step = step * 2;
end
end

function x = inverseHadamardTransformRows(y)
x = hadamardTransformRows(y) / size(y, 2);
end
