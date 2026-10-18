function llrValues = initLlr(receivedSignal, noiseVariance)
% INITLLR Calculates the Log-Likelihood Ratio (LLR) for BPSK signals in an AWGN channel.
%
% DESCRIPTION:
%   Calculates LLR values based on the received soft symbols, signal
%   amplitude, and noise variance.
%   Formula: LLR = (2 / sigma^2) * y
%
% INPUTS:
%   receivedSignal  - Soft symbol values after coherent integration (vector or scalar).
%   signalAmplitude - Theoretical signal amplitude after integration (noiseless) (scalar).
%   noiseVariance   - Noise power/variance per channel after integration (scalar).
%
% OUTPUTS:
%   llrValues       - Calculated LLR values (same dimension as receivedSignal).

    %% Calculate Channel Reliability Factor
    channelReliability = 2  / noiseVariance;

    %% Calculate LLR
    llrValues = channelReliability * receivedSignal;

end