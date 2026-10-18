function primaryCode = generateBdsDataPrimaryCode(settings)
%%=========================================================================
%   Generate one BDS data-component ranging code.
%   PRIMARYCODE = GENERATEBDSDATAPRIMARYCODE(SETTINGS) returns a bipolar
%   (+1/-1), 10230-chip primary code for the selected data component.
%
%   Implemented code assignments:
%       B1C data : PRN 1 (truncated Weil code, w = 2678, p = 699)
%       B2a data : PRN 1 (extended Gold code)
%       B2b I    : PRN 6 (the first public-service B2b code assignment)
%
%   B2b public-service ranging-code assignments start at PRN 6, so PRN 6
%   is used instead of inventing a non-standard B2b PRN 1.
%   Parameters and chip convention were cross-checked against PocketSDR's
%   public sdr_code.py implementation.
%%=========================================================================

    if ~isfield(settings, 'signalName') || ~isfield(settings, 'prn')
        error('generateBdsDataPrimaryCode:MissingSettings', ...
            'settings.signalName and settings.prn are required.');
    end

    switch upper(settings.signalName)
        case 'B1C'
            requirePrn(settings.prn, 1, 'BDS B1C data');
            primaryCode = generateB1cDataPrn1();

        case 'B2A'
            requirePrn(settings.prn, 1, 'BDS B2a data');
            primaryCode = generateB2aDataPrn1();

        case 'B2B'
            requirePrn(settings.prn, 6, 'BDS B2b I');
            primaryCode = generateB2bIPrn6();

        otherwise
            error('generateBdsDataPrimaryCode:UnsupportedSignal', ...
                'Unsupported BDS signal "%s".', settings.signalName);
    end
end
