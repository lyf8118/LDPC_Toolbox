function [decodedCodeword, realIter] = snemsDecode(llrMatrix, settings, neuralParams)
%SNEMSDECODE Layer-shared neural EMS inference decoder for BDS B2b.

settings = prepareB2bLdpcSettings(settings);
graph = getB2bLdpcGraph(settings);

if nargin < 3 || isempty(neuralParams)
    neuralParams = loadB2bNeuralParams(settings, 'SNEMS');
end

c2vWeights = single(neuralParams.c2vWeights);
vnWeights = single(neuralParams.vnWeights);
intrinsicLlr = single(llrMatrix);

varToCheckMsg = zeros(graph.numEdges, settings.gfSize, 'single');
checkToVarMsg = zeros(graph.numEdges, settings.gfSize, 'single');

[~, minIndices] = min(intrinsicLlr, [], 2);
decodedCodeword = double(minIndices - 1).';

for edgeIdx = 1:graph.numEdges
    varToCheckMsg(edgeIdx, :) = permuteV2C(graph.edgeWeights(edgeIdx), ...
        intrinsicLlr(graph.colIndices(edgeIdx), :), settings.gfMulTable);
end

realIter = settings.maxIterations;
if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
    realIter = 0;
    return;
end

for iter = 1:settings.maxIterations
    c2vIter = min(iter, size(c2vWeights, 3));
    vnIter = min(iter, size(vnWeights, 3));
    sharedC2vWeight = c2vWeights(1, 1, c2vIter);

    for checkIdx = 1:settings.rowH
        connectedEdges = graph.cnConnections{checkIdx};
        for edgePos = 1:numel(connectedEdges)
            targetEdge = connectedEdges(edgePos);
            aggregatedLlr = [];
            for sourcePos = 1:numel(connectedEdges)
                sourceEdge = connectedEdges(sourcePos);
                if sourceEdge ~= targetEdge
                    aggregatedLlr = optExtMinSum(aggregatedLlr, ...
                        varToCheckMsg(sourceEdge, :), settings);
                end
            end

            aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
            rawMsg = permuteC2V(graph.edgeWeights(targetEdge), ...
                aggregatedLlr, settings.gfMulTable);
            weightedMsg = sharedC2vWeight * rawMsg;
            checkToVarMsg(targetEdge, :) = 0.5 * weightedMsg + 0.5 * tanh(weightedMsg);
        end
    end

    posteriorLlr = intrinsicLlr;
    for edgeIdx = 1:graph.numEdges
        posteriorLlr(graph.colIndices(edgeIdx), :) = ...
            posteriorLlr(graph.colIndices(edgeIdx), :) + checkToVarMsg(edgeIdx, :);
    end

    beta = vnWeights(1, 1, vnIter);
    posteriorLlr = intrinsicLlr + beta * (posteriorLlr - intrinsicLlr);
    posteriorLlr = posteriorLlr - min(posteriorLlr, [], 2);

    [~, minIdx] = min(posteriorLlr, [], 2);
    decodedCodeword = double(minIdx - 1).';

    for edgeIdx = 1:graph.numEdges
        extrinsicMsg = posteriorLlr(graph.colIndices(edgeIdx), :) - checkToVarMsg(edgeIdx, :);
        extrinsicMsg = extrinsicMsg - min(extrinsicMsg);
        varToCheckMsg(edgeIdx, :) = permuteV2C(graph.edgeWeights(edgeIdx), ...
            extrinsicMsg, settings.gfMulTable);
    end

    if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
        realIter = iter;
        return;
    end
end
end
