function code = generateB2bIPrn6()
%GENERATEB2BIPRN6 Generate the first public-service B2b-I ranging code.

    persistent cachedCode
    if isempty(cachedCode)
        g1Base = generateLfsrCode(8190, ...
            hex2dec('1FFF'), hex2dec('1019'));
        g1 = [g1Base, g1Base(1:2040)];
        g2 = generateLfsrCode(10230, ...
            hex2dec('11AE'), hex2dec('0693'));
        cachedCode = g1 .* g2;
    end
    code = cachedCode;
end
