function [decodedCodeword, realIter] = emsDecode(llrMatrix, settings)
%EMSDECODE Extended Min-Sum decoder for BDS B2b non-binary LDPC.

settings = prepareB2bLdpcSettings(settings);
graph = getB2bLdpcGraph(settings);

currentLlrMatrix = single(llrMatrix);
[~, minIndices] = min(currentLlrMatrix, [], 2);
decodedCodeword = double(minIndices - 1).';

varToCheckMsg = zeros(graph.numEdges, settings.gfSize, 'single');
checkToVarMsg = zeros(graph.numEdges, settings.gfSize, 'single');

for edgeIdx = 1:graph.numEdges
    varIdx = graph.colIndices(edgeIdx);
    edgeWeight = graph.edgeWeights(edgeIdx);
    varToCheckMsg(edgeIdx, :) = permuteV2C(edgeWeight, ...
        currentLlrMatrix(varIdx, :), settings.gfMulTable);
end

realIter = settings.maxIterations;
if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
    realIter = 0;
    return;
end

for iter = 1:settings.maxIterations
    for checkIdx = 1:settings.rowH
        connectedEdges = graph.cnConnections{checkIdx};
        for edgePos = 1:numel(connectedEdges)
            targetEdge = connectedEdges(edgePos);
            aggregatedLlr = [];
            for sourcePos = 1:numel(connectedEdges)
                sourceEdge = connectedEdges(sourcePos);
                if sourceEdge ~= targetEdge
                    aggregatedLlr = extMinSum(aggregatedLlr, ...
                        varToCheckMsg(sourceEdge, :), settings);
                end
            end

            aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
            if settings.offset > 0
                aggregatedLlr = max(aggregatedLlr - settings.offset, 0);
            elseif settings.alpha > 0 && settings.alpha < 1
                aggregatedLlr = aggregatedLlr * settings.alpha;
            end

            edgeWeight = graph.edgeWeights(targetEdge);
            checkToVarMsg(targetEdge, :) = permuteC2V(edgeWeight, ...
                aggregatedLlr, settings.gfMulTable);
        end
    end

    for varIdx = 1:settings.colH
        connectedEdges = graph.vnConnections{varIdx};
        baseLlr = currentLlrMatrix(varIdx, :);
        for edgePos = 1:numel(connectedEdges)
            targetEdge = connectedEdges(edgePos);
            extrinsicLlr = baseLlr;
            for sourcePos = 1:numel(connectedEdges)
                sourceEdge = connectedEdges(sourcePos);
                if sourceEdge ~= targetEdge
                    extrinsicLlr = extrinsicLlr + checkToVarMsg(sourceEdge, :);
                end
            end

            extrinsicLlr = extrinsicLlr - min(extrinsicLlr);
            edgeWeight = graph.edgeWeights(targetEdge);
            varToCheckMsg(targetEdge, :) = permuteV2C(edgeWeight, ...
                extrinsicLlr, settings.gfMulTable);
        end
    end

    for varIdx = 1:settings.colH
        connectedEdges = graph.vnConnections{varIdx};
        for edgePos = 1:numel(connectedEdges)
            currentLlrMatrix(varIdx, :) = currentLlrMatrix(varIdx, :) + ...
                checkToVarMsg(connectedEdges(edgePos), :);
        end
        currentLlrMatrix(varIdx, :) = currentLlrMatrix(varIdx, :) - ...
            min(currentLlrMatrix(varIdx, :));
        [~, minIdx] = min(currentLlrMatrix(varIdx, :));
        decodedCodeword(varIdx) = minIdx - 1;
    end

    if isValidB2bCodeword(decodedCodeword, graph.hMatrix, settings)
        realIter = iter;
        return;
    end
end
end
