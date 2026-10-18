function [normIp, normSigma2]= noiseEst(I_P, Q_P, settings)
% =========================================================================
% Function Name: noiseEst
% Description:
%   Performs blind Signal-to-Noise Ratio (SNR) estimation using the 
%   Moment Method (M2M4) based on the squared magnitude (Z = I^2 + Q^2), 
%   and normalizes the prompt correlation values for soft-decision decoding.
%
% Algorithm:
%   Uses statistical moments of Z to solve for signal amplitude (A) and 
%   noise variance (sigma^2). Adaptive to both Real and Complex noise models.
%
% Inputs:
%   I_P      : [1 x N] Prompt I-branch correlation sums 
%   Q_P      : [1 x N] Prompt Q-branch correlation sums 
%   settings : Configuration structure (requires .bitsPerSymbol, .colH)
%
% Outputs:
%   normIp     : [K x M] Normalized soft bits (I_bar = I / A)
%                Formatted matrix for LDPC decoder input.
%   normSigma2 : Normalized noise variance (sigma_bar^2 = sigma^2 / A^2)
%                Used for Log-Likelihood Ratio (LLR) computation.
% =========================================================================
  %% Noise Estimation (Unified Moment Estimator using Z = I^2 + Q^2)=======
    % This estimator works for both cases:
    % - Complex noise: Q contains noise -> use Var(Z)
    % - Q degenerates to 0: fall back to real M2M4 -> use Var(Z)/2

    tiny = 1e-12;
    I = I_P(:);
    Q = Q_P(:);

    Z     = I.^2 + Q.^2;
    meanZ = mean(Z);
    varZ  = var(Z, 1);          % population variance, matches moment definition
    qVar  = var(Q, 1);

    if qVar > tiny
        % Complex-noise / IQ-noise case:
        % meanZ = A^2 + 2*sigma^2,  varZ = 4*A^2*sigma^2 + 4*sigma^4
        Pav = sqrt(max(meanZ^2 - varZ, 0));          % Pav = A^2
        estNoiseVar  = 0.5 * max(meanZ - Pav, 0);    % sigma^2 (single-branch)
    else
        % Q degenerates to 0 (real case):
        % meanZ = A^2 + sigma^2,  varZ = 4*A^2*sigma^2 + 2*sigma^4
        Pav = sqrt(max(meanZ^2 - varZ/2, 0));        % Pav = A^2
        estNoiseVar  = 1.0 * max(meanZ - Pav, 0);    % sigma^2 (single-branch)
    end

    estSignalAmp = sqrt(max(Pav, 0));                % A
    estSignalAmp = max(estSignalAmp, tiny);          % avoid divide-by-zero

    %% Normalize for decoder===============================================
    normIp = I_P / estSignalAmp;
    normSigma2  = estNoiseVar / (estSignalAmp^2);

    %% Format Output for Decoder===========================================
    normIp = reshape(normIp, settings.bitsPerSymbol, settings.colH).';

end