function code = generateGpsL1cDataPrn1()
%GENERATEGPSL1CDATAPRN1 Generate the GPS L1C-D PRN 1 primary code.

    persistent cachedCode
    if ~isempty(cachedCode)
        code = cachedCode;
        return;
    end

    legendreLength = 10223;
    weilIndex = 5097;
    insertionIndex = 181;

    legendre = generateGpsLegendreSequence(legendreLength);
    chipNumber = 0:legendreLength-1;
    shiftedIndex = mod(chipNumber + weilIndex, legendreLength) + 1;
    weilCode = legendre .* legendre(shiftedIndex);

    % Fixed seven-chip insertion sequence 0110100, mapped as
    % binary 0 -> +1 and binary 1 -> -1.
    insertionCode = [1, -1, -1, 1, -1, 1, 1];
    cachedCode = [weilCode(1:insertionIndex-1), insertionCode, ...
        weilCode(insertionIndex:end)];

    code = cachedCode;
end
