% =========================================================================
% SCRIPT: ldpcEmsBDSDemo.m
% DESCRIPTION:
%   Main script to simulate and analyze the Bit Error Rate (BER) performance 
%   of GNSS signals (B1C, B2a, B2b) using LDPC decoding.
%
%   The script performs the following steps:
%   1. Loads signal-specific configurations.
%   2. Runs Monte Carlo simulations across a range of C/N0 levels.
%   3. Logs the BER/FER/avgIter performance for analysis.
% =========================================================================

%% Clean up the environment first =========================================
close all; clear; clc;
format ('compact');
format ('long', 'g');
%%   Add common utility functions to MATLAB path
currentDir = fileparts(mfilename('fullpath'));
commonPath = fullfile(fileparts(currentDir), 'Common');
addpath(commonPath);
%% Simulation Fidelity Configuration ======================================
% Select Signal Simulation Type：
% 1. 'SAMPLE_LEVEL' (Engineering Fidelity)
%    - Simulates full IF waveform generation and Integrate-and-Dump.
%    - Requires blind noise variance estimation .
%    - Captures implementation losses and estimation errors.
%
% 2. 'SYMBOL_LEVEL' (Theoretical Baseline)
%    - Generates statistical equivalent correlator outputs directly.
%    - Assumes perfect synchronization and known noise variance .
%    - Used for fast LDPC validation and theoretical bounds checking.
simLevel = 'SYMBOL_LEVEL';


%%  Configuration =========================================================
% Select target signal type: 
% 1.'B1C_2' - Subframe 2 of the BDS B-CNAV1 Navigation Message
% 2.'B1C_3' - Subframe 3 of the BDS B-CNAV1 Navigation Message
% 3.'B2a'   - BDS B-CNAV2 Navigation Message
% 4.'B2b'   - BDS B-CNAV3 Navigation Message
messageType = 'B1C_2';

% Load configuration parameters from factory function
settings = initSettings(messageType,simLevel);

%%  Simulation ============================================================
fprintf('>>> Starting Simulation for Target Signal: %s <<<\n', messageType);

% Pre-allocate memory for results matrix [1 x C/N0 Steps]
% Note: Assuming settings.cn0Range is a row vector
numCn0Steps = length(settings.cn0Range);
berResults  = zeros(1, numCn0Steps);
ferResults  = zeros(1, numCn0Steps);
avgIterResults = zeros(1, numCn0Steps);
avgTimeResults = zeros(1, numCn0Steps);

totalSimTic = tic;

% --- Main Simulation Loop ---
for idx = 1:numCn0Steps
    stepTic = tic;
    % Extract current C/N0 for this iteration
    currentCn0 = settings.cn0Range(idx);
    
    % Initialize error accumulator for Monte Carlo trials
    totalBer = 0; 
    totalFer = 0;
    totalIter = 0;

    % --- Monte Carlo Trials ---
    parfor trialIdx = 1:settings.numTrials
        % -------------------------- Encoding -----------------------------
        [ldpcInMsg, originalData] = ldpcEncoder(settings);
        normIp = [];
        normSigma2 = [];
        switch settings.simLevel
            case 'SAMPLE_LEVEL'
                % -----------------Engineering Path-----------------------
                [I_P, Q_P] = genStreamedSampleLevelIQ( ...
                    ldpcInMsg, currentCn0, settings);
                
                % ESTIMATE noise from the signal
                [normIp, normSigma2] = noiseEst(I_P, Q_P, settings); 
                
            case 'SYMBOL_LEVEL'
                % -----------------Theoretical Path----------------------
                [I_P, Q_P] = genStatEquivalentIQ(ldpcInMsg, currentCn0, settings);
                
                % the noise variance (sigma=1)
                % This bypasses the estimator error.
                normIp = I_P; 
                normSigma2 = 1; % Ideal normalized variance
         end
        
        % -------------------------- Decoding -----------------------------
        [ldpcOutMsg,iterCount] = ldpcDecoderBDS(normIp, normSigma2, settings);
        
        %-------------------------BER Calculation  ------------------------
        % Compare decoded bits with the original ground truth
        berMetric = calculateBER(ldpcOutMsg, originalData, settings);

        % Accumulate iter
        totalIter = totalIter + iterCount;
        % Accumulate BER
        totalBer = totalBer + berMetric;
        % Accumulate FER
        if berMetric > 0
            totalFer = totalFer + 1;
        end
    end
    
    stepTime = toc(stepTic);

    % Calculate average BER for the corresponding C/No value
    berResults(idx) = totalBer / settings.numTrials;
    ferResults(idx) = totalFer / settings.numTrials;
    avgIterResults(idx) = totalIter / settings.numTrials;
    avgTimeResults(idx) = stepTime / settings.numTrials;
    % Log progress to console
    fprintf('    |-- C/N0: %2.1f dB-Hz | BER: %.2e | FER: %.2e | AvgIter: %.2f\n', ...
        currentCn0, berResults(idx), ferResults(idx),avgIterResults(idx));
end
%% ============================
totalSimTime = toc(totalSimTic);

fprintf('\n    --- Time per C/N0 Breakdown ---\n');
for idx = 1:numCn0Steps
    fprintf('    C/N0: %2.1f dB-Hz  ->  %.4f s/trial\n', settings.cn0Range(idx), avgTimeResults(idx));
end
fprintf('\n');

%% ===============================  Result Analysis =======================
% Visualize the BER performance
plotResults(berResults,ferResults,avgIterResults,settings);

fprintf('>>> Simulation Complete. \n');
