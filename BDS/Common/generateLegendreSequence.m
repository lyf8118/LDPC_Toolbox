function legendre = generateLegendreSequence(sequenceLength)
% Generate the bipolar Legendre sequence used by the B1C Weil code.
    legendre = ones(1, sequenceLength);
    values = 1:sequenceLength-1;
    quadraticResidues = mod(values .* values, sequenceLength) + 1;
    legendre(unique(quadraticResidues)) = -1;
end