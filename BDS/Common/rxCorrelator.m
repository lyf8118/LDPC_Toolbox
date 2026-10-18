function [I_P, Q_P] = rxCorrelator(ifSignal, settings)
% =========================================================================
% Function: rxCorrelator
% Description:
%   Simulates a perfectly synchronized BDS data correlator.  It performs
%   real-IF carrier wipe-off, front-end low-pass filtering, the matched
%   signal-specific modulation wipe-off, and coherent integration over each
%   encoded bit.
%
% Input:
%   ifSignal : [1 x TotalSamples] Received IF signal with noise
%   settings : Configuration structure
%
% Output:
%   I_P      : [1 x N_sym] Prompt I-branch correlation sums
%   Q_P      : [1 x N_sym] Prompt Q-branch correlation sums
% =========================================================================

    %% 1. Parameters Setup
    validateattributes(ifSignal, {'numeric'}, {'vector', 'real', 'nonempty'}, ...
        mfilename, 'ifSignal');
    T_int = settings.dataBitTime * 1e-3;
    samplesPerBit = round(settings.samplingFreq * T_int);
    totalSamples = length(ifSignal);
    
    numBits = floor(totalSamples / samplesPerBit);
    processingLen = numBits * samplesPerBit;
    
    inputSigTrunc = ifSignal(1:processingLen);
    tVec = (0:processingLen-1) / settings.samplingFreq;

    %% 2. Local Carrier Generation 
    omega = 2 * pi * settings.intermediateFreq;
    localCarrier = exp(-1i * omega * tVec);

    %% 3. Down-conversion and front-end low-pass filtering
    baseband_IQ = 2 * inputSigTrunc .* localCarrier;
    baseband_IQ = applyFrontendLowpass(baseband_IQ, settings);
    
    %% 4. Modulation wipe-off and coherent integration
    % Reshape to separate each symbol's samples into columns
    iqMatrix = reshape(baseband_IQ, samplesPerBit, numBits);

    localDataReplica = generateDataModulationReplica(settings, samplesPerBit);
    correlationResults = localDataReplica * iqMatrix;
    
    % Extract I and Q components
    I_P = real(correlationResults);
    Q_P = imag(correlationResults);

end
