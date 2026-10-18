function [llrMatrix, promptI, promptQ] = simulatedSignalChannel(binaryCodeword, currentCn0, settings)
%SIMULATEDSIGNALCHANNEL Generate symbol-level correlator statistics.
%   This function keeps its legacy name for compatibility with the training
%   and test scripts.  It implements the same normalized correlator-output
%   model as BDS/Common/genStatEquivalentIQ and does not generate sampled
%   waveforms or perform carrier processing and coherent integration.
%
%   For each LDPC encoded bit, under coherent BPSK in AWGN with perfect
%   synchronization and carrier phase,
%
%       I = sqrt(2*(C/N0)*T)*b + n_I
%       Q = n_Q
%
%   where b is +1/-1, T is the coherent integration time, and n_I and n_Q
%   are independent N(0,1) variables.  The known normalized single-branch
%   noise variance is therefore one.
%
%   Inputs:
%       binaryCodeword : [colH x gfBits] encoded bits (0/1)
%       currentCn0     : carrier-to-noise-density ratio (dB-Hz)
%       settings       : decoder and signal settings
%
%   Outputs:
%       llrMatrix      : [colH x gfSize] initial GF-symbol metrics
%       promptI        : [colH x gfBits] equivalent Prompt-I statistics
%       promptQ        : [colH x gfBits] equivalent Prompt-Q statistics

    expectedSize = [settings.colH, settings.gfBits];
    if ~isequal(size(binaryCodeword), expectedSize)
        error('simulatedSignalChannel:InvalidCodewordSize', ...
            'binaryCodeword must have size [%d x %d].', ...
            settings.colH, settings.gfBits);
    end

    % Convert C/N0 to the mean amplitude of the normalized correlator output.
    linearCn0 = 10^(currentCn0 / 10);
    integrationTime = settings.dataBitTime * 1e-3;
    signalAmplitude = sqrt(2 * linearCn0 * integrationTime);

    % BPSK mapping and direct generation of one I/Q statistic per coded bit.
    bpskBits = 1 - 2 * double(binaryCodeword);
    promptI = signalAmplitude .* bpskBits + randn(size(bpskBits));
    promptQ = randn(size(bpskBits));

    % The statistical model is normalized to unit noise variance per branch.
    normalizedNoiseVariance = 1;
    llrMatrix = initLlr(promptI, normalizedNoiseVariance, settings);
end
