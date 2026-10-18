function B_Str=deci2bin(Z,n)
B_Str=zeros(1,n);
tmp=dec2bin(Z,n);
for i=1:length(tmp)
    B_Str(i)=str2double(tmp(i));
end
