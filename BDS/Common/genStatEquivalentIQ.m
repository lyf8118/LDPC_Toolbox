function [I_P, Q_P] = genStatEquivalentIQ(ldpcInMsg, cn0, settings)
% =========================================================================
% Function: genStatEquivalentIQ
% Description:
%   Statistical equivalent model for GNSS correlator outputs.
%   Directly generates I_P and Q_P based on SNR theory, bypassing 
%   waveform generation and integration.
%
% Input:
%   ldpcInMsg : [1 x N] Transmitted bits/symbols (+1/-1)
%   cn0       : Carrier-to-Noise density ratio (dB-Hz)
%   settings  : Configuration structure (requires dataBitTime)
%
% Output:
%   I_P       : [1 x N] Prompt I-branch correlation sums (Normalized)
%   Q_P       : [1 x N] Prompt Q-branch correlation sums (Normalized)
% =========================================================================

    %% 1. Parameter Calculation============================================
    % Convert C/N0 from dB-Hz to linear scale ratio (Hz)
    % C/N0_dB = 10*log10(C/N0_lin) => C/N0_lin = 10^(C/N0_dB / 10)
    linearCn0 = 10^(cn0 / 10);
    
    % Integration time T (seconds)
    T_int = settings.dataBitTime * 1e-3; 
    
    % Number of symbols
    numSymbols = length(ldpcInMsg);
    
    %% 2. Signal Component Calculation=====================================
    % Theoretically, for coherent BPSK in AWGN:
    % Signal Amplitude (Normalized) = sqrt(2 * (C/N0) * T)
    % This normalization assumes the noise variance sigma^2 = 1.
    signalAmp = sqrt(2 * linearCn0 * T_int);
    
    %% 3. Noise Generation=================================================
    % Generate standard normal noise for I and Q branches
    % n_I, n_Q ~ N(0, 1)
    noise_I = randn(1, numSymbols);
    noise_Q = randn(1, numSymbols);
    
    %% 4. Construct Correlator Outputs=====================================
    % I_P contains the signal (modulated by bits) plus noise
    % Q_P contains only noise (assuming perfect carrier tracking, phi=0)
    I_P = (signalAmp * ldpcInMsg) + noise_I;
    Q_P = noise_Q;
    I_P = reshape(I_P, settings.bitsPerSymbol, settings.colH).';

end