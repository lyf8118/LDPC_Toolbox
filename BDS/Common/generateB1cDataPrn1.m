function code = generateB1cDataPrn1()
%GENERATEB1CDATAPRN1 Generate B1C-D PRN 1 truncated Weil code.
%   The parameters follow BDS-SIS-ICD-B1C-1.0: w = 2678, p = 699.

    persistent cachedCode
    if isempty(cachedCode)
        sequenceLength = 10243;
        codeLength = 10230;
        phaseDifference = 2678;
        truncationPoint = 699;

        legendre = generateLegendreSequence(sequenceLength);
        chipNumber = 0:codeLength-1;
        weilIndex = mod(chipNumber + truncationPoint - 1, sequenceLength);
        cachedCode = legendre(weilIndex + 1) .* ...
            legendre(mod(weilIndex + phaseDifference, sequenceLength) + 1);
    end
    code = cachedCode;
end
