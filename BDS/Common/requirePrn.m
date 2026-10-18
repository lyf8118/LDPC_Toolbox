function requirePrn(actualPrn, expectedPrn, signalName)
%REQUIREPRN Validate the implemented PRN assignment for a BDS signal.
    if actualPrn ~= expectedPrn
        error('generateBdsDataPrimaryCode:UnsupportedPrn', ...
            '%s currently implements PRN %d only.', signalName, expectedPrn);
    end
end
