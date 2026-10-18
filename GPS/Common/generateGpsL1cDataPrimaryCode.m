function primaryCode = generateGpsL1cDataPrimaryCode(settings)
%GENERATEGPSL1CDATAPRIMARYCODE Generate the GPS L1C-D PRN 1 primary code.
%   PRIMARYCODE = GENERATEGPSL1CDATAPRIMARYCODE(SETTINGS) returns the
%   10230-chip L1C data-component ranging code in bipolar form (+1/-1).
%
%   This implementation intentionally supports PRN 1 only. IS-GPS-800
%   assigns PRN 1 the L1C-D Weil index w = 5097 and insertion index p =
%   181. The BOC(1,1) subcarrier is applied later by
%   generateDataModulationReplica; it is not included here.
%   Parameters and chip convention were cross-checked against PocketSDR's
%   public sdr_code.py implementation.

    if ~isfield(settings, 'prn') || settings.prn ~= 1
        error('generateGpsL1cDataPrimaryCode:UnsupportedPrn', ...
            'This waveform model currently implements GPS L1C-D PRN 1 only.');
    end

    primaryCode = generateGpsL1cDataPrn1();
end
