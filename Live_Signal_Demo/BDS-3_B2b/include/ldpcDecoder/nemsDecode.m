function [decodedCodeword, realIter] = nemsDecode(llrMatrix, settings, neuralParams)
%NEMSDECODE Edge-weighted neural EMS inference decoder for BDS B2b.

settings = prepareB2bLdpcSettings(settings);
graph = getB2bLdpcGraph(settings);

if nargin < 3 || isempty(neuralParams)
    neuralParams = loadB2bNeuralParams(settings, 'NEMS');
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
            weight = c2vWeights(min(targetEdge, size(c2vWeights, 1)), 1, c2vIter);
            weightedMsg = weight * rawMsg;
            checkToVarMsg(targetEdge, :) = 0.5 * weightedMsg + 0.5 * tanh(weightedMsg);
        end
    end

    nextVarToCheckMsg = varToCheckMsg;
    for varIdx = 1:settings.colH
        connectedEdges = graph.vnConnections{varIdx};
        totalLlr = intrinsicLlr(varIdx, :) + sum(checkToVarMsg(connectedEdges, :), 1);
        beta = vnWeights(1, 1, vnIter);
        posteriorLlr = intrinsicLlr(varIdx, :) + beta * (totalLlr - intrinsicLlr(varIdx, :));
        posteriorLlr = posteriorLlr - min(posteriorLlr);
        [~, minIdx] = min(posteriorLlr);
        decodedCodeword(varIdx) = minIdx - 1;

        for edgePos = 1:numel(connectedEdges)
            edgeIdx = connectedEdges(edgePos);
            extrinsicMsg = posteriorLlr - checkToVarMsg(edgeIdx, :);
            extrinsicMsg = extrinsicMsg - min(extrinsicMsg);
            nextVarToCheckMsg(edgeIdx, :) = permuteV2C(graph.edgeWeights(edgeIdx), ...
                extrinsicMsg, settings.gfMulTable);
        end
    end

    varToCheckMsg = nextVarToCheckMsg;
    if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
        realIter = iter;
        return;
    end
end
end
