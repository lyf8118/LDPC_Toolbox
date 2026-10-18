function syms = gf2bin(code)
    N_GF = 6;
    n = length(code);
    syms = zeros(1, n * N_GF, 'uint8');
    for i = 1:n
        for j = 1:N_GF
            syms((i-1)*N_GF + j) = bitget(code(i), N_GF - j + 1);
        end
    end
end