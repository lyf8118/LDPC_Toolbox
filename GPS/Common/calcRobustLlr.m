% =========================================================================
% Sub-function: calcRobustLLR
% Description:
%   Implements the Analytic Solution for LLR calculation under uncertain CSI.
%   Formula based on Eq. 21 - 24 from the reference paper.
% =========================================================================
function llr = calcRobustLlr(y_n, mu_dB, sigma_dB)

    % Constants
    LN10_OVER_10 = 0.2302585; % ln(10)/10
    
    % Ensure sigma_dB is not zero to avoid division by zero in 'a'
    % If sigma_dB is very small, it converges to linear LLR, but numerically unstable.
    % We clamp it to a small value.
    min_sigma = 1e-3; 
    sigma_dB = max(sigma_dB, min_sigma);
    
    % Step 1: Convert stats to natural log domain (Eq. 23, 24)
    mu_lambda    = mu_dB * LN10_OVER_10;
    sigma_lambda = sigma_dB * LN10_OVER_10;
    
    % Step 2: Calculate hyper-parameters a and b (Eq. 22)
    % a ~ 1/sigma_lambda
    a_param = 1 / sigma_lambda;
    
    % b ~ sigma^2 * exp(mu + sigma^2/2)
    b_param = (sigma_lambda^2) * exp(mu_lambda + (sigma_lambda^2 / 2));
    
    % Step 3: Compute LLR (Eq. 21)
    % LLR = -(a + 0.5) * [ ln(1/b + (y-1)^2/2) - ln(1/b + (y+1)^2/2) ]
    
    term_common = 1.0 / b_param;
    term_minus  = (y_n - 1.0).^2 / 2.0;
    term_plus   = (y_n + 1.0).^2 / 2.0;
    
    log_part = log(term_common + term_minus) - log(term_common + term_plus);
    
    llr = -(a_param + 0.5) * log_part;

end