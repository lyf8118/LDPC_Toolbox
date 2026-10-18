% =========================================================================
% SCRIPT: compareldpc.m
% DESCRIPTION:
%   Evaluates and compares the BER and FER performance of various Non-Binary 
%   LDPC decoding algorithms (e.g., EMS, FFT-QSPA, QSPA, NEMS, SNEMS) for 
%   BDS navigation signals under identical channel conditions. The script 
%   utilizes a unified Monte Carlo simulation architecture and implements 
%   strict dynamic path isolation to ensure experimental integrity.
%
% DEPENDENCIES:
%   - A 'Common' directory in the root folder containing base functions.
%   - Individual algorithm directories (e.g., EMS/, QSPA/) containing their 
%     specific 'ldpcDecoderBDS.m' implementations.
% =========================================================================

%% 1. Environment Initialization & Dependency Loading =========================
close all; clear; clc;
format compact;
format long g;

rootDir = fileparts(mfilename('fullpath'));
commonPath = fullfile(rootDir, 'Common');

if exist(commonPath, 'dir')
    addpath(genpath(commonPath));
else
    error('[Error] Directory ''Common'' not found! Please check the path structure.');
end

%% 2. Global Simulation Parameter Configuration ===============================
% Select target signal type: 
% 'B1C_2' - Subframe 2 of the BDS B-CNAV1 Navigation Message
% 'B1C_3' - Subframe 3 of the BDS B-CNAV1 Navigation Message
% 'B2a'   - BDS B-CNAV2 Navigation Message
% 'B2b'   - BDS B-CNAV3 Navigation Message
messageType = 'B2b'; 

algoFolders = {'EMS', 'FFT-QSPA', 'QSPA', 'NEMS', 'SNEMS'};
algoNames   = {'EMS', 'FFT-QSPA', 'QSPA', 'NEMS', 'SNEMS'};

%% 3. Simulation Fidelity Configuration =======================================
% Select Signal Simulation Type:
% 1. 'SAMPLE_LEVEL' (Engineering Fidelity)
%    - Simulates full IF waveform generation and Integrate-and-Dump.
%    - Requires blind noise variance estimation.
%    - Captures implementation losses and estimation errors.
%
% 2. 'SYMBOL_LEVEL' (Theoretical Baseline)
%    - Generates statistical equivalent correlator outputs directly.
%    - Assumes perfect synchronization and known noise variance.
%    - Used for fast LDPC validation and theoretical bounds checking.
simLevel = 'SYMBOL_LEVEL';

baseSettings = initSettings(messageType, simLevel);
cn0Range     = baseSettings.cn0Range;
numCn0Steps  = length(cn0Range);
results      = struct();

%% 4. Main Loop: Multi-Algorithm Comparison Simulation ========================
for aIdx = 1:length(algoFolders)
    currentAlgo = algoFolders{aIdx};
    algoPath    = fullfile(rootDir, currentAlgo);
    
    fprintf('\n>>> [Simulation Start] Current Algorithm: %s <<<\n', currentAlgo);
    if exist(algoPath, 'dir')
        addpath(genpath(algoPath)); 
    else
        fprintf('[Warning] Directory %s not found. Skipping.\n', currentAlgo);
        continue; 
    end
    
    % Initialize dedicated configuration for the current algorithm
    settings = initSettings(messageType, simLevel);
    berCurve  = zeros(1, numCn0Steps);
    ferCurve  = zeros(1, numCn0Steps);
    iterCurve = zeros(1, numCn0Steps); 
    
    for cIdx = 1:numCn0Steps
        currentCn0 = settings.cn0Range(cIdx);
        
        totalBerAccum  = 0; 
        totalFerAccum  = 0; 
        totalIterAccum = 0; 
        
        % --- Parallel Monte Carlo Trials ---
        parfor trialIdx = 1:settings.numTrials
            
            % [1. Transmitter] GF(q) Source Generation & LDPC Encoding
            [ldpcInMsg, orgData] = ldpcEncoder(settings);
            
            normIp = [];
            normSigma2 = [];
            
            % [2. Channel] Channel Modeling & Front-End Processing
            switch settings.simLevel
                case 'SAMPLE_LEVEL'
                    % Engineering Path
                    [I_P, Q_P] = genStreamedSampleLevelIQ( ...
                        ldpcInMsg, currentCn0, settings);
                    [normIp, normSigma2] = noiseEst(I_P, Q_P, settings); 
                    
                case 'SYMBOL_LEVEL'
                    % Theoretical Path
                    [I_P, Q_P] = genStatEquivalentIQ(ldpcInMsg, currentCn0, settings);
                    normIp = I_P; 
                    normSigma2 = 1; % Ideal normalized variance
            end
            
            % [3. Receiver] Non-Binary LDPC Decoding
            [ldpcOutMsg, iter] = ldpcDecoderBDS(normIp, normSigma2, settings);
            
            % [4. Metrics] Error Statistics Calculation
            berVal = calculateBER(ldpcOutMsg, orgData, settings);
            
            totalBerAccum  = totalBerAccum + berVal;
            totalIterAccum = totalIterAccum + iter;
            
            if berVal > 0
                totalFerAccum = totalFerAccum + 1;
            end
        end
        
        % Calculate Mean Performance Metrics
        berCurve(cIdx)  = totalBerAccum / settings.numTrials;
        ferCurve(cIdx)  = totalFerAccum / settings.numTrials;
        iterCurve(cIdx) = totalIterAccum / settings.numTrials;
        
        fprintf('   C/N0:%2.1f| Frames:%d| BER:%.2e| FER:%.2e| AvgIter:%.2f\n', ...
            currentCn0, settings.numTrials, berCurve(cIdx), ferCurve(cIdx), iterCurve(cIdx));
    end
    
    % Archive Current Algorithm Results
    results(aIdx).name = algoNames{aIdx};
    results(aIdx).BER  = berCurve;
    results(aIdx).FER  = ferCurve;
    results(aIdx).Iter = iterCurve;
    results(aIdx).Cn0  = cn0Range;
    
    % Unload Path to prevent Function Shadowing
    rmpath(genpath(algoPath));
end

%% 5. Data Analysis & Visualization ===========================================
fprintf('\n>>> Generating performance plots...\n');
plotMultiAlgoResults(results, messageType, settings.maxIterations);
fprintf('>>> Simulation complete.\n');
