% function res = boxPlus(x, y)
% % boxPlus Implementation of the "boxplus" operator for SPA.
% %   x [+] y = 2 * atanh( tanh(x/2) * tanh(y/2) )
% %   Numerical stability logic applied to prevent inf/nan.
% 
%     % Limit inputs to avoid tanh(x) becoming purely +/- 1 causing atanh(1) -> Inf
%     % 30 is sufficient as tanh(15) is extremely close to 1.
%     limit = 30; 
%     x = max(min(x, limit), -limit);
%     y = max(min(y, limit), -limit);
% 
%     res = 2 * atanh(tanh(x/2) * tanh(y/2));
% end
function res = boxPlus(x, y)
% boxPlus Implementation using Jacobian Logarithm (Gallager's exact formula).
%   x [+] y = sign(x)*sign(y)*min(|x|,|y|) + log(1+e^{-|x+y|}) - log(1+e^{-|x-y|})
%   This provides absolute numerical stability without arbitrary hard limits.

    % 1. 符号位与极性处理
    signX = sign(x); signX(signX == 0) = 1;
    signY = sign(y); signY(signY == 0) = 1;
    
    % 2. 核心幅度 (这其实就是 Min-Sum 的部分)
    minVal = min(abs(x), abs(y));
    
    % 3. 严格补偿项 (这正是 BP 优于 Min-Sum 的原因)
    % log(1 + exp(-x)) 在 x 很大时极其趋近于 0，天然稳定
    corr = log(1 + exp(-abs(x + y))) - log(1 + exp(-abs(x - y)));
    
    % 4. 组合结果
    res = signX .* signY .* minVal + corr;
end