function [I_P, Q_P] = genStreamedSampleLevelIQ(ldpcInMsg, cn0, settings)
%GENSTREAMEDSAMPLELEVELIQ Generate and correlate a BDS waveform in chunks.
%   [I_P,Q_P] = GENSTREAMEDSAMPLELEVELIQ(LDPCINMSG,CN0,SETTINGS) preserves
%   the sample-level PRN, signal-specific modulation, carrier, AWGN and
%   coherent-integration path, but never stores the complete frame waveform
%   in memory.

    validateattributes(ldpcInMsg, {'numeric'}, {'vector', 'real', 'nonempty'}, ...
        mfilename, 'ldpcInMsg');
    validateattributes(cn0, {'numeric'}, {'scalar', 'real', 'finite'}, ...
        mfilename, 'cn0');

    integrationTime = settings.dataBitTime * 1e-3;
    samplesPerSymbol = round(settings.samplingFreq * integrationTime);
    symbolReplica = generateDataModulationReplica(settings, samplesPerSymbol);
    symbolReplicaColumn = symbolReplica(:);

    symbolCount = numel(ldpcInMsg);
    I_P = zeros(1, symbolCount);
    Q_P = zeros(1, symbolCount);

    symbolsPerChunk = getSymbolsPerChunk(settings, samplesPerSymbol, symbolCount);
    carrierAmplitude = getCarrierAmplitude(cn0, settings);
    angularFrequency = 2 * pi * settings.intermediateFreq;
    noiseSigma = settings.gwnAmp;
    frontEndCoef = getFliterCoef(settings);

    for firstSymbol = 1:symbolsPerChunk:symbolCount
        lastSymbol = min(firstSymbol + symbolsPerChunk - 1, symbolCount);
        chunkSymbols = double(ldpcInMsg(firstSymbol:lastSymbol));
        chunkSymbolCount = numel(chunkSymbols);

        % One column is one encoded navigation symbol. The deterministic
        % waveform explicitly contains the sampled signal-specific PRN.
        receivedChunk = carrierAmplitude * ...
            (symbolReplicaColumn * chunkSymbols);

        firstSample = (firstSymbol - 1) * samplesPerSymbol;
        sampleNumber = firstSample + ...
            (0:samplesPerSymbol * chunkSymbolCount - 1);
        carrierPhase = reshape(angularFrequency * ...
            (sampleNumber / settings.samplingFreq), ...
            samplesPerSymbol, chunkSymbolCount);

        % Real-IF transmit/ADC path.
        receivedChunk = receivedChunk .* cos(carrierPhase);
        receivedChunk = receivedChunk + generateRealNoise(noiseSigma, ...
            samplesPerSymbol, chunkSymbolCount);

        % Receiver path: complex down-conversion -> LPF -> matched
        % signal-specific code/modulation correlation.
        basebandChunk = 2 * receivedChunk .* exp(-1i * carrierPhase);
        basebandChunk = applyFrontendLowpass( ...
            basebandChunk, settings, frontEndCoef);

        correlationResults = symbolReplica * basebandChunk;
        I_P(firstSymbol:lastSymbol) = real(correlationResults);
        Q_P(firstSymbol:lastSymbol) = imag(correlationResults);
    end
end

function symbolsPerChunk = getSymbolsPerChunk(settings, samplesPerSymbol, symbolCount)
    defaultChunkSamples = 1e6;
    if isfield(settings, 'waveformChunkSamples') && ...
            isfinite(settings.waveformChunkSamples) && ...
            settings.waveformChunkSamples > 0
        chunkSamples = floor(settings.waveformChunkSamples);
    else
        chunkSamples = defaultChunkSamples;
    end
    symbolsPerChunk = max(1, floor(chunkSamples / samplesPerSymbol));
    symbolsPerChunk = min(symbolsPerChunk, symbolCount);
end

function carrierAmplitude = getCarrierAmplitude(cn0, settings)
    linearCn0 = 10^(cn0 / 10);
    % For real AWGN with variance 2*gwnAmp^2 and a cosine carrier whose
    % average power is A^2/2, this scale makes cn0 the DATA-component C/N0.
    carrierAmplitude = 2 * sqrt(2) * settings.gwnAmp * ...
        sqrt(linearCn0 / settings.samplingFreq);
end

function noise = generateRealNoise(noiseSigma, rowCount, columnCount)
    noise = noiseSigma * sqrt(2) * randn(rowCount, columnCount);
end
