% =========================================================================
% SCRIPT: ldpcEmsParamSweepIter.m
% DESCRIPTION:
%   Performance comparison of LDPC decoding with different Maximum 
%   Iterations (maxIterations = 10, 15, 20).
%   Fixed nm_ems based on initSettings (default).
% =========================================================================

%% 1. Environment Cleanup & Path Setup ====================================
close all; clear; clc;
format ('compact'); format ('long', 'g');
currentDir = fileparts(mfilename('fullpath'));
commonPath = fullfile(fileparts(currentDir), 'Common');
addpath(commonPath);

%% Global Configuration ===================================================
simLevel = 'SYMBOL_LEVEL'; % Recommended for speed
messageType = 'B2b';

% Initialize base settings
baseSettings = initSettings(messageType, simLevel);

% --- Define Parameter Sweep Range (Iterations) ---
iterList = [10, 15, 20]; 
numIterScenarios = length(iterList);

% Pre-allocate Result Matrices (Rows: Iteration scenarios, Cols: C/N0 points)
numCn0Steps = length(baseSettings.cn0Range);
berResults  = zeros(numIterScenarios, numCn0Steps);
ferResults  = zeros(numIterScenarios, numCn0Steps);
avgIterResults = zeros(numIterScenarios, numCn0Steps);

%% Main Simulation Loop (Parameter Sweep) =================================
fprintf('>>> Starting Simulation: %s Signal (%s Mode) <<<\n', messageType, simLevel);
fprintf('>>> Sweeping Max Iterations: [%s] <<<\n', num2str(iterList));

for sIdx = 1:numIterScenarios
    % ---------- Update Settings for current scenario ---------------------
    currentIter = iterList(sIdx);
    settings = baseSettings; % Copy base settings
    
    % [Key Change]: Update maxIterations instead of nmEms
    settings.maxIterations = currentIter; 

    fprintf('\n--- Scenario %d/%d: MaxIterations = %d (nm_ems = %d) ---\n', ...
        sIdx, numIterScenarios, settings.maxIterations, settings.nmEms);
    
    % --------------- Iterate over C/N0 Range -----------------------------
    for cIdx = 1:numCn0Steps
        currentCn0 = settings.cn0Range(cIdx);
        
        % Reset accumulators
        totalBer = 0; 
        totalFer = 0; 
        totalIter = 0;
        
        %  Parallel Monte Carlo Trials
        parfor trialIdx = 1:settings.numTrials
            % --- Encoding ---
            [ldpcInMsg, originalData] = ldpcEncoder(settings);
       
            % Initialize parfor temporary variables
            normIp = []; normSigma2 = [];
            
            % --------------------- Channel & Receiver --------------------
            switch settings.simLevel
                case 'SAMPLE_LEVEL'
                    [I_P, Q_P] = genStreamedSampleLevelIQ( ...
                        ldpcInMsg, currentCn0, settings);
                    [normIp, normSigma2] = noiseEst(I_P, Q_P, settings); 
                    
                case 'SYMBOL_LEVEL'
                    [I_P, ~] = genStatEquivalentIQ(ldpcInMsg, currentCn0, settings);
                    normIp = I_P; 
                    normSigma2 = 1; 
            end
            
            % ---------------------- Decoding -----------------------------
            % Note: Check variables are used directly as requested
            [ldpcOutMsg, iterCount] = ldpcDecoderBDS(normIp, normSigma2, settings);
            
            % ----------------- Error Calculation -------------------------
            berMetric = calculateBER(ldpcOutMsg, originalData, settings);
            
            % ----------------------- Accumulate --------------------------
            totalIter = totalIter + iterCount;
            totalBer  = totalBer + berMetric;
            if berMetric > 0
                totalFer = totalFer + 1;
            end
        end
        
        % ---------------------- Store Results ----------------------------
        berResults(sIdx, cIdx)  = totalBer / settings.numTrials;
        ferResults(sIdx, cIdx)  = totalFer / settings.numTrials;
        avgIterResults(sIdx, cIdx) = totalIter / settings.numTrials;
        
        fprintf('   IterMax=%2d | C/N0: %2.1f | BER: %.2e | FER: %.2e | AvgRealIter: %.1f\n', ...
            currentIter, currentCn0, berResults(sIdx, cIdx), ferResults(sIdx, cIdx), avgIterResults(sIdx, cIdx));
    end
end

%% Visualization ==========================================================
fprintf('\n>>> Simulation Complete. Generating Plots... \n');

% Pass the iteration list to the settings for plotting purposes
baseSettings.iterList = iterList;

plotIterResults(berResults, ferResults, avgIterResults, baseSettings, 'EMS');
