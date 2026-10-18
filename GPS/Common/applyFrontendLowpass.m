function filteredSignal = applyFrontendLowpass(basebandSignal, settings, coef)
%APPLYFRONTENDLOWPASS Apply the receiver LPF and remove its group delay.
%   Matrix inputs are serialized column-wise so filtering remains
%   continuous across all symbols in the current waveform chunk.

    if nargin < 3 || isempty(coef)
        coef = getFliterCoef(settings);
    end

    inputSize = size(basebandSignal);
    serializedSignal = basebandSignal(:);
    groupDelay = settings.FeOrder / 2;
    tailPadding = zeros(groupDelay, 1, 'like', serializedSignal);
    causalOutput = filter(coef, 1, [serializedSignal; tailPadding]);
    filteredSignal = causalOutput(groupDelay + 1: ...
        groupDelay + numel(serializedSignal));
    filteredSignal = reshape(filteredSignal, inputSize);
end
