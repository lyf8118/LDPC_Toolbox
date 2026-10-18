function coef = getFliterCoef(settings)
%GETFLITERCOEF Design the real-IF receiver low-pass FIR.
%   The real waveform is first mixed to complex baseband.  FeBandwidth is
%   the total two-sided bandwidth, so the one-sided LPF cutoff is
%   FeBandwidth/2.  The normalized FIR1 cutoff is therefore
%   FeBandwidth/samplingFreq, matching the supplied reference function.

    validateRealIfSettings(settings);
    normalizedCutoff = settings.FeBandwidth / settings.samplingFreq;
    coef = fir1(settings.FeOrder, normalizedCutoff, 'low');
end

function validateRealIfSettings(settings)
    requiredFields = {'fileType', 'IF', 'FeBandwidth', ...
        'samplingFreq', 'FeOrder'};
    for fieldIndex = 1:numel(requiredFields)
        if ~isfield(settings, requiredFields{fieldIndex})
            error('getFliterCoef:MissingSetting', ...
                'settings.%s is required.', requiredFields{fieldIndex});
        end
    end

    if settings.fileType ~= 1
        error('getFliterCoef:RealIfOnly', ...
            'Only real-IF waveform simulation (settings.fileType = 1) is supported.');
    end
    validateattributes(settings.IF, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, mfilename, 'settings.IF');
    validateattributes(settings.FeBandwidth, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive', '<', settings.samplingFreq}, ...
        mfilename, 'settings.FeBandwidth');
    validateattributes(settings.samplingFreq, {'numeric'}, ...
        {'scalar', 'real', 'finite', 'positive'}, ...
        mfilename, 'settings.samplingFreq');
    validateattributes(settings.FeOrder, {'numeric'}, ...
        {'scalar', 'integer', 'positive'}, mfilename, 'settings.FeOrder');

    if mod(settings.FeOrder, 2) ~= 0
        error('getFliterCoef:OddOrder', ...
            'settings.FeOrder must be even for integer group-delay compensation.');
    end
    if settings.IF - settings.FeBandwidth / 2 <= 0
        error('getFliterCoef:PassbandCrossesDc', ...
            'The real-IF passband must remain strictly above DC.');
    end
    if settings.IF + settings.FeBandwidth / 2 >= settings.samplingFreq / 2
        error('getFliterCoef:AliasedPassband', ...
            'The real-IF passband must remain strictly below Nyquist.');
    end
end
