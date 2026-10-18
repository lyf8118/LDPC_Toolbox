function code = bin2gf(syms)
    N_GF = 6;  
    n = length(syms) / N_GF;
    code = zeros(1, n, 'uint8');
    for i = 1:n
        for j = 1:N_GF
            code(i) = bitshift(code(i), 1) + syms((i-1)*N_GF + j );
        end
    end
end