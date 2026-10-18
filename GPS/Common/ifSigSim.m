function ifSignal = ifSigSim(ldpcInMsg, cn0, settings)
% =========================================================================
% Function: ifSigSim
% Description:
%   Simulates the GPS L1C data-channel IF waveform and AWGN transmission.
%   In SIGNAL_SPECIFIC mode, L1C data symbols are shaped by the
%   sine-phased BOC(1,1) subcarrier selected by settings.messageType.
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
    
    % Build one data-symbol modulation replica. For L1C this is the PRN 1
    % data code with BOC(1,1). kron applies the same aligned replica
    % to every encoded navigation symbol without allocating a second
    % frame-sized modulation buffer.
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
    % For GPS L1C data, s_data(t) is the aligned PRN 1 code multiplied by
    % the BOC(1,1) subcarrier.
    ifSignal = (carrierAmplitude * txDataStream) .* carrierVec + noiseVec;

end
