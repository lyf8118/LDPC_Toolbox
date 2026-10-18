function combinedLlr = optExtMinSum(llrVec1, llrVec2, settings)
%OPTEXTMINSUM L-shape optimized EMS check-node operation.

settings = prepareB2bLdpcSettings(settings);

if isempty(llrVec1)
    combinedLlr = single(llrVec2);
    return;
elseif isempty(llrVec2)
    combinedLlr = single(llrVec1);
    return;
end

truncationSize = min(settings.nmEms, settings.gfSize);
[sortedLlr1, sortedIndices1] = sort(llrVec1);
[sortedLlr2, sortedIndices2] = sort(llrVec2);

saturationValue = sortedLlr1(truncationSize) + sortedLlr2(truncationSize);
combinedLlr = saturationValue * ones(1, settings.gfSize, 'single');

idx1Fixed = sortedIndices1(1) - 1;
idx2Fixed = sortedIndices2(1) - 1;
combinedLlr(bitxor(idx1Fixed, idx2Fixed) + 1) = sortedLlr1(1) + sortedLlr2(1);

for j = 2:truncationSize
    xorIndex = bitxor(idx1Fixed, sortedIndices2(j) - 1) + 1;
    candidate = sortedLlr1(1) + sortedLlr2(j);
    if candidate < combinedLlr(xorIndex)
        combinedLlr(xorIndex) = candidate;
    end
end

for i = 2:truncationSize
    xorIndex = bitxor(sortedIndices1(i) - 1, idx2Fixed) + 1;
    candidate = sortedLlr1(i) + sortedLlr2(1);
    if candidate < combinedLlr(xorIndex)
        combinedLlr(xorIndex) = candidate;
    end
end
end
