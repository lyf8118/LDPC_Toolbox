function legendre = generateGpsLegendreSequence(sequenceLength)
%GENERATEGPSLEGENDRESEQUENCE Generate the bipolar GPS L1C Legendre sequence.

    legendre = ones(1, sequenceLength);
    values = 1:sequenceLength-1;
    quadraticResidues = mod(values .* values, sequenceLength) + 1;
    legendre(unique(quadraticResidues)) = -1;
end
