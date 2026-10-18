function isValid = isValidB2bCodeword(decodedCodeword, hMatrix, settings)
%ISVALIDB2BCODEWORD Check the GF(64) LDPC syndrome.

codewordGf = gf(double(decodedCodeword(:).'), settings.gfBits);
hMatrixGf = gf(hMatrix.', settings.gfBits);
syndrome = codewordGf * hMatrixGf;
isValid = all(syndrome == 0);
end
