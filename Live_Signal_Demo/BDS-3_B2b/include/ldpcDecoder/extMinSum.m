function combinedLlr = extMinSum(llrVec1, llrVec2, settings)
%EXTMINSUM Elementary check-node operation for EMS in GF(64).

settings = prepareB2bLdpcSettings(settings);

if isempty(llrVec1)
    combinedLlr = single(llrVec2);
    return;
elseif isempty(llrVec2)
    combinedLlr = single(llrVec1);
    return;
end

truncationSize = min(settings.nmEms, settings.gfSize);
[~, sortedIndices1] = sort(llrVec1);
[~, sortedIndices2] = sort(llrVec2);

saturationValue = llrVec1(sortedIndices1(truncationSize)) + ...
    llrVec2(sortedIndices2(truncationSize));
combinedLlr = saturationValue * ones(1, settings.gfSize, 'single');

for i = 1:truncationSize
    for j = 1:truncationSize
        xorIndex = bitxor(sortedIndices1(i) - 1, sortedIndices2(j) - 1) + 1;
        candidate = llrVec1(sortedIndices1(i)) + llrVec2(sortedIndices2(j));
        if candidate < combinedLlr(xorIndex)
            combinedLlr(xorIndex) = candidate;
        end
    end
end
end
