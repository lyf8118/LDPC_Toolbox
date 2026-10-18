function code = generateB2aDataPrn1()
%GENERATEB2ADATAPRN1 Generate the extended Gold code for B2a-D PRN 1.
%   G1 resets after chip 8190 while G2 runs continuously.

    persistent cachedCode
    if isempty(cachedCode)
        g1Base = generateLfsrCode(8190, ...
            hex2dec('1FFF'), hex2dec('1105'));
        g1 = [g1Base, g1Base(1:2040)];
        g2 = generateLfsrCode(10230, ...
            hex2dec('1025'), hex2dec('0517'));
        cachedCode = g1 .* g2;
    end
    code = cachedCode;
end
