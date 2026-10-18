function symbolProbabilities = initQspaProbabilities(receivedSignal, sigmaSquaredNorm, settings)
%INITQSPAPROBABILITIES Convert B2b soft bits into GF(64) symbol probabilities.

settings = prepareB2bLdpcSettings(settings);
receivedSignal = double(receivedSignal);

gfBitTable = dec2bin(0:settings.gfSize-1, settings.gfBits) - '0';
bitLlrs = 2 * receivedSignal ./ sigmaSquaredNorm;
bitLlrs = max(min(bitLlrs, 20), -20);

probBitZero = 1 ./ (1 + exp(-bitLlrs));
probBitOne = 1 - probBitZero;
probBitZero = max(probBitZero, realmin);
probBitOne = max(probBitOne, realmin);

logProbZero = log(probBitZero);
logProbOne = log(probBitOne);
logLikelihoods = logProbZero * (1 - gfBitTable).' + logProbOne * gfBitTable.';

logLikelihoods = logLikelihoods - max(logLikelihoods, [], 2);
symbolProbabilities = exp(logLikelihoods);
symbolProbabilities = symbolProbabilities ./ sum(symbolProbabilities, 2);
end
