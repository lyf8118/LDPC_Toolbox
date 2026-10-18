function combinedLlr = ext_min_sum(llrVec1, llrVec2)
%EXT_MIN_SUM Compatibility wrapper for extMinSum.

settings = prepareB2bLdpcSettings(struct());
combinedLlr = extMinSum(llrVec1, llrVec2, settings);
end
