function [decodedCodeword, realIter] = nmsDecode(llr, hMatrix, settings, neuralParams)
%NMSDECODE Compatibility wrapper for the learned NeuralMS decoder.

[decodedCodeword, realIter] = neuralmsDecode(llr, hMatrix, settings, neuralParams);
end
