function invValue = gfInverse(value, gfMulTable)
%GFINVERSE Return the multiplicative inverse of a non-zero GF(64) element.

if value == 0
    error('gfInverse:ZeroElement', 'GF(64) zero has no multiplicative inverse.');
end

invValue = find(gfMulTable(value + 1, :) == 1, 1) - 1;
end
