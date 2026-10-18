function binaryCodeword = encodingB1C_2(infoSymbols)
%ENCODINGB1C_2 Encode one B-CNAV1 Subframe 2 LDPC information block.
%   BINARYCODEWORD = ENCODINGB1C_2(INFOSYMBOLS) encodes 100 GF(64)
%   information symbols into the systematic 200-symbol LDPC codeword
%   defined by BDS-SIS-ICD-B1C-1.0, Section 6.2.2.2. The result is a
%   200-by-6 binary matrix using the ICD's MSB-first symbol mapping.

    gfBits = 6;

    persistent parityGenerator
    if isempty(parityGenerator)
        % Keep a single authoritative H matrix for encoding and decoding.
        % Cache the fixed generator so Monte Carlo trials do not repeat the
        % same GF matrix inversion for every codeword.
        [~, ~, hMatrix] = getHInformationB1C_2();
        hMatrixGf = gf(hMatrix, gfBits);

        % H = [H1 H2], codeword = [m p], and over GF(2^6):
        % H1*m' + H2*p' = 0, hence p' = H2\H1*m'.
        h1 = hMatrixGf(:, 1:100);
        h2 = hMatrixGf(:, 101:200);
        parityGenerator = (h2 \ h1).';
    end

    infoSymbolsGf = gf(infoSymbols, gfBits);
    paritySymbolsGf = infoSymbolsGf * parityGenerator;
    codewordGf = [infoSymbolsGf, paritySymbolsGf];

    numericCodeword = double(codewordGf.x);
    binaryCodeword = dec2bin(numericCodeword.', gfBits) - '0';
end
