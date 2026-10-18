function [normalizedPromptI, sigmaSquaredNorm, promptQ] = sigSim(ldpcInMsg, cn0, settings)
%SIGSIM Generate symbol-level GPS correlator-output statistics.
%   One equivalent Prompt I/Q pair is generated directly for each encoded
%   bit.  No sampled waveform, carrier wipe-off, correlation loop, or blind
%   moment-based noise estimation is performed.
%
%   Under coherent BPSK in AWGN with perfect synchronization and carrier
%   phase, the unit-noise correlator model is
%
%       I = sqrt(2*(C/N0)*T)*b + n_I
%       Q = n_Q
%
%   where b is +1/-1 and n_I,n_Q are independent N(0,1) variables.  The
%   first two outputs retain the legacy normalized interface expected by the
%   NMS training and test code: E[normalizedPromptI|b] = b and its known
%   noise variance is returned in sigmaSquaredNorm.
%
%   Inputs:
%       ldpcInMsg : transmitted BPSK encoded bits (+1/-1)
%       cn0       : carrier-to-noise-density ratio (dB-Hz)
%       settings  : signal and decoder settings
%
%   Outputs:
%       normalizedPromptI : normalized Prompt-I soft values
%       sigmaSquaredNorm  : known normalized I-branch noise variance
%       promptQ           : unit-noise Prompt-Q statistics (optional)

    if ~isvector(ldpcInMsg) || numel(ldpcInMsg) ~= settings.colH
        error('sigSim:InvalidMessageSize', ...
            'ldpcInMsg must be a vector containing %d encoded bits.', ...
            settings.colH);
    end

    linearCn0 = 10^(cn0 / 10);
    integrationTime = settings.dataBitTime * 1e-3;
    signalAmplitude = sqrt(2 * linearCn0 * integrationTime);

    inputSize = size(ldpcInMsg);
    promptI = signalAmplitude .* double(ldpcInMsg) + randn(inputSize);
    promptQ = randn(inputSize);

    normalizedPromptI = promptI / signalAmplitude;
    sigmaSquaredNorm = 1 / (signalAmplitude^2);
end
