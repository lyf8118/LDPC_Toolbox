function gfMulTable = getGfTable()
%GETGFTABLE Return the GF(64) multiplication lookup table for B2b LDPC.

persistent cachedTable
if ~isempty(cachedTable)
    gfMulTable = cachedTable;
    return;
end

gfBits = 6;
gfSize = 2^gfBits;

gfExpTable = [1, 2, 4, 8, 16, 32, 3, 6, 12, 24, 48, 35, 5, 10, 20, 40, ...
    19, 38, 15, 30, 60, 59, 53, 41, 17, 34, 7, 14, 28, 56, 51, 37, ...
    9, 18, 36, 11, 22, 44, 27, 54, 47, 29, 58, 55, 45, 25, 50, 39, ...
    13, 26, 52, 43, 21, 42, 23, 46, 31, 62, 63, 61, 57, 49, 33];

gfLogTable = [0, 0, 1, 6, 2, 12, 7, 26, 3, 32, 13, 35, 8, 48, 27, 18, ...
    4, 24, 33, 16, 14, 52, 36, 54, 9, 45, 49, 38, 28, 41, 19, 56, ...
    5, 62, 25, 11, 34, 31, 17, 47, 15, 23, 53, 51, 37, 44, 55, 40, ...
    10, 61, 46, 30, 50, 22, 39, 43, 29, 60, 42, 21, 20, 59, 57, 58];

gfMulTable = zeros(gfSize, gfSize, 'uint8');
for left = 1:gfSize-1
    for right = 1:gfSize-1
        powerSum = gfLogTable(left + 1) + gfLogTable(right + 1);
        gfMulTable(left + 1, right + 1) = gfExpTable(mod(powerSum, gfSize - 1) + 1);
    end
end

cachedTable = gfMulTable;
end
