function ifSignal = ifSigSim(ldpcInMsg, cn0, settings)
% =========================================================================
% Function: ifSigSim
% Description:
%   Simulates the selected BDS data-channel IF waveform and AWGN
%   transmission.  B1C uses BOC(1,1), while B2a/B2b retain BPSK(10)
%   according to settings.messageType.
%
% Input:
%   ldpcInMsg : [1 x N] Transmitted bits/symbols (+1/-1)
%   cn0       : Carrier-to-Noise density ratio (dB-Hz)
%   settings  : Configuration structure
%
% Output:
%   ifSignal  : [1 x TotalSamples] Real IF signal samples
% =========================================================================

    %% 1. Calculate Signal Amplitude and Noise Power
    % Convert C/N0 from dB-Hz to linear scale
    linearCn0 = 10^(cn0 / 10);
    
    % Calculate noise variance (sigma) based on settings
    noiseSigma = settings.gwnAmp;
    
    if settings.fileType ~= 1
        error('ifSigSim:RealIfOnly', ...
            'Only real-IF waveform simulation (settings.fileType = 1) is supported.');
    end

    % Calculate real carrier amplitude A
    carrierAmplitude = 2 * sqrt(2) * noiseSigma * ...
        sqrt(linearCn0 / settings.samplingFreq);

    %% 2. Generate Baseband Data Stream 
    T_int = settings.dataBitTime * 1e-3; % Duration of one symbol (s)
    samplesPerBit = round(settings.samplingFreq * T_int);
    
    % Generate one signal-specific PRN-spread data-symbol replica. B1C uses
    % BOC(1,1); B2a/B2b use their BPSK(10) data-component ranging codes.
    dataReplica = generateDataModulationReplica(settings, samplesPerBit);
    txDataStream = kron(ldpcInMsg, dataReplica);
    
    totalSamples = length(txDataStream);
    tVec = (0:totalSamples-1) / settings.samplingFreq;

    %% 3. Carrier Modulation and AWGN Addition
    omega = 2 * pi * settings.intermediateFreq;
    
    % A real ADC sees a cosine IF carrier and real AWGN.
    carrierVec = cos(omega * tVec);
    noiseVec = noiseSigma * sqrt(2) * randn(1, totalSamples);
    
    % r(t) = A * d(t) * s_data(t) * cos(wt) + n(t)
    ifSignal = (carrierAmplitude * txDataStream) .* carrierVec + noiseVec;

end
