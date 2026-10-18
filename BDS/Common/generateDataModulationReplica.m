function replica = generateDataModulationReplica(settings, samplesPerBit)
%GENERATEDATAMODULATIONREPLICA Create one sampled data-symbol replica.
%   REPLICA = GENERATEDATAMODULATIONREPLICA(SETTINGS, SAMPLESPERBIT)
%   returns the unit-magnitude PRN-spread waveform used by both the
%   transmitter and the perfectly synchronized prompt correlator.
%
%   B1C data uses PRN 1 with sine-phased BOC(1,1). B2a data uses PRN 1
%   with BPSK(10). B2b uses PRN 6, the first public-service B2b-I code.
%   Perfect code-phase synchronization is assumed at the receiver.

    validateattributes(samplesPerBit, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'samplesPerBit');

    if isfield(settings, 'waveformMode') && ...
            strcmpi(settings.waveformMode, 'BPSK_EQUIVALENT')
        replica = ones(1, samplesPerBit);
        return;
    end

    if ~isfield(settings, 'modulationType')
        error('generateDataModulationReplica:MissingModulationType', ...
            'settings.modulationType is required for SAMPLE_LEVEL simulation.');
    end

    primaryCode = generateBdsDataPrimaryCode(settings);
    prnReplica = samplePrimaryCode(primaryCode, settings, samplesPerBit);

    switch upper(settings.modulationType)
        case 'BOC11'
            if ~isfield(settings, 'subcarrierFreq') || settings.subcarrierFreq <= 0
                error('generateDataModulationReplica:InvalidSubcarrier', ...
                    'A positive settings.subcarrierFreq is required for BOC(1,1).');
            end

            sampleIndex = 0:samplesPerBit-1;
            halfChipIndex = floor(sampleIndex * ...
                (2 * settings.subcarrierFreq / settings.samplingFreq) + 1e-10);
            subcarrierReplica = 1 - 2 * mod(halfChipIndex, 2);
            replica = prnReplica .* subcarrierReplica;

        case {'BPSK', 'BPSK10'}
            replica = prnReplica;

        otherwise
            error('generateDataModulationReplica:UnsupportedModulation', ...
                'Unsupported modulationType "%s".', settings.modulationType);
    end
end

function sampledCode = samplePrimaryCode(primaryCode, settings, sampleCount)
% Sample the periodic chip sequence without assuming integer samples/chip.
    sampleIndex = 0:sampleCount-1;
    chipIndex = floor(sampleIndex * ...
        (settings.codeFreqBasis / settings.samplingFreq) + 1e-10);
    chipIndex = mod(chipIndex, numel(primaryCode)) + 1;
    sampledCode = primaryCode(chipIndex);
end
