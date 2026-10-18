% =========================================================================
% SCRIPT: ldpcEmsParamSweepNm.m
% DESCRIPTION:
%   Performance comparison of LDPC decoding with different EMS truncation 
%   sizes (nm = 4, 8, 16).
% =========================================================================

%% 1. Environment Cleanup & Path Setup=====================================
close all; clear; clc;
format ('compact'); format ('long', 'g');

currentDir = fileparts(mfilename('fullpath'));
commonPath = fullfile(fileparts(currentDir), 'Common');
addpath(commonPath);

%% Global Configuration====================================================
simLevel = 'SYMBOL_LEVEL'; % Recommended for speed
messageType = 'B2b';

% Initialize base settings
baseSettings = initSettings(messageType, simLevel);

% --- Define Parameter Sweep Range ---
nmList = [4, 8, 16]; 
numNmScenarios = length(nmList);

% Pre-allocate Result Matrices (Rows: nm scenarios, Cols: C/N0 points)
numCn0Steps = length(baseSettings.cn0Range);
berResults  = zeros(numNmScenarios, numCn0Steps);
ferResults  = zeros(numNmScenarios, numCn0Steps);
avgIterResults = zeros(numNmScenarios, numCn0Steps);

%% Main Simulation Loop (Parameter Sweep)==================================
fprintf('>>> Starting Simulation: %s Signal (%s Mode) <<<\n', messageType, simLevel);

for nIdx = 1:numNmScenarios
    % ----------Update Settings for current scenario----------------------
    currentNm = nmList(nIdx);
    settings = baseSettings; % Copy base settings
    settings.nmEms = currentNm; % Overwrite parameter
    
    fprintf('\n--- Scenario %d/%d: nm_ems = %d ---\n', nIdx, numNmScenarios, currentNm);
    
    %--------------- Iterate over C/N0 Range-------------------------------
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
                    [I_P, Q_P] = genStatEquivalentIQ(ldpcInMsg, currentCn0, settings);
                    normIp = I_P; 
                    normSigma2 = 1; 
            end
            
            % ----------------------Decoding ------------------------------
            [ldpcOutMsg, iterCount] = ldpcDecoderBDS(normIp, normSigma2, settings);
            
            % ----------------- Error Calculation -------------------------
            berMetric = calculateBER(ldpcOutMsg, originalData, settings);
            
            % -----------------------Accumulate----------------------------
            totalIter = totalIter + iterCount;
            totalBer  = totalBer + berMetric;
            if berMetric > 0
                totalFer = totalFer + 1;
            end
        end
        
        % ---------------------- Store Results-----------------------------
        berResults(nIdx, cIdx)  = totalBer / settings.numTrials;
        ferResults(nIdx, cIdx)  = totalFer / settings.numTrials;
        avgIterResults(nIdx, cIdx) = totalIter / settings.numTrials;
        
        fprintf('   nm=%2d | C/N0: %2.1f | BER: %.2e | FER: %.2e | AvgIter: %.1f\n', ...
            currentNm, currentCn0, berResults(nIdx, cIdx), ferResults(nIdx, cIdx), avgIterResults(nIdx, cIdx));
    end
end

%%  Visualization ========================================================
fprintf('\n>>> Simulation Complete. Generating Plots... \n');

% Pass the full matrices to the plot function
% The function will handle multiple lines automatically
baseSettings.nmList = nmList;
plotNmResults(berResults, ferResults, avgIterResults, baseSettings,'EMS');
