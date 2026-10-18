% =========================================================================
% SCRIPT: compare_ldpc_algorithms_gps.m
% DESCRIPTION:
%   Evaluates and compares the BER and FER performance of various LDPC
%   decoding algorithms (e.g., BP, MS, NeuralMS) for GPS L1C (CNAV-2) 
%   signals under identical channel conditions. The script uses a unified 
%   Monte Carlo simulation architecture and implements strict dynamic path 
%   isolation to ensure experimental integrity and prevent namespace pollution.
%
% DEPENDENCIES:
%   - A 'Common' directory in the root folder containing base functions.
%   - Individual algorithm directories (e.g., BP/, MS/) containing their 
%     specific 'ldpcDecoderGPS.m' implementations.
% =========================================================================

%%  Environment Initialization & Dependency Loading =========================
close all; clear; clc;
format compact;
format long g;

% Retrieve the absolute path of the current script
rootDir = fileparts(mfilename('fullpath'));
commonPath = fullfile(rootDir, 'Common');

% Load common dependency library (base path only to avoid subfolder interference)
if exist(commonPath, 'dir')
    addpath(commonPath); 
else
    error('[Error] Directory ''Common'' not found! Please check the project tree structure.');
end

%%  Global Simulation Parameter Configuration ===============================
algoFolders = {'BP', 'MS', 'NeuralMS'};
algoNames   = {'Belief Propagation', 'Min-Sum', 'Neural MS'};

% Signal and Channel Configuration
messageType = 'L1C_2';          % Target Signal: GPS CNAV-2 Subframe 2
simLevel    = 'SAMPLE_LEVEL';   % Fidelity Level: 'SAMPLE_LEVEL' (Engineering) or 'SYMBOL_LEVEL' (Theoretical)

% Pre-initialize to fetch environment parameters (e.g., C/N0 step range)
tempSettings = initSettings(messageType, simLevel);
cn0Range     = tempSettings.cn0Range;
numCn0Steps  = length(cn0Range);

% Initialize structure to store simulation results
results = struct();

%%  Main Loop: Multi-Algorithm Comparison Simulation ========================
for aIdx = 1:length(algoFolders)
    currentAlgo = algoFolders{aIdx};
    algoPath    = fullfile(rootDir, currentAlgo);
    
    % Verify algorithm module integrity
    if ~exist(algoPath, 'dir')
        fprintf('[Warning] Algorithm support package ''%s'' does not exist. Skipping this branch.\n', currentAlgo);
        continue; 
    end
    
    % --- Namespace Isolation & Dynamic Loading ---
    % Bring the current algorithm's path to the top of the search path to ensure 
    % the correct 'ldpcDecoderGPS' core function is overridden and utilized.
    addpath(genpath(algoPath));
    fprintf('\n>>> [Simulation Start] Current Algorithm: %s (%s) <<<\n', algoNames{aIdx}, currentAlgo);
    
    % Initialize dedicated configuration for the current algorithm
    settings = initSettings(messageType, simLevel);
    
    % Pre-allocate performance metric matrices for the current algorithm
    berCurve  = zeros(1, numCn0Steps);
    ferCurve  = zeros(1, numCn0Steps);
    iterCurve = zeros(1, numCn0Steps);
    
    % --- Carrier-to-Noise Ratio (C/N0) Sweep ---
    for cIdx = 1:numCn0Steps
        currentCn0 = cn0Range(cIdx);
        
        % Accumulators for Bit Errors, Frame Errors, and Iterations
        totalBerAccum  = 0; 
        totalFerAccum  = 0; 
        totalIterAccum = 0; 
        
        % --- Parallel Monte Carlo Trials ---
        parfor trialIdx = 1:settings.numTrials
            
            % -------------------------------------------------------------
            % Source Generation & LDPC Encoding
            % -------------------------------------------------------------
            [ldpcInMsg, orgData] = ldpcEncoder(settings);
            
            % -------------------------------------------------------------
            %  Channel Modeling & Front-End Processing
            % -------------------------------------------------------------
            if strcmp(settings.simLevel, 'SAMPLE_LEVEL')
                % Engineering Link: IF Signal Gen -> Rx Correlator Integrate & Dump -> Noise Variance Est
                [I_P, Q_P] = genStreamedSampleLevelIQ( ...
                    ldpcInMsg, currentCn0, settings);
                [normIp, normSigma2] = noiseEst(I_P, Q_P); 
            else
                % Theoretical Link: Direct generation of statistically equivalent I/Q branch soft information
                [I_P, Q_P] = genStatEquivalentIQ(ldpcInMsg, currentCn0, settings);
                normIp = I_P; 
                normSigma2 = 1; % Ideal normalized variance
            end
            
            % -------------------------------------------------------------
            % LDPC Decoding & Post-Processing
            % -------------------------------------------------------------
            % Dynamically invoke the decoder implementation under the current 'algoPath'
            [ldpcOutMsg, iterCount] = ldpcDecoderGPS(normIp, normSigma2, settings);
            
            % -------------------------------------------------------------
            %  Error Statistics Calculation
            % -------------------------------------------------------------
            berVal = calculateBER(ldpcOutMsg, orgData);
            
            totalBerAccum  = totalBerAccum + berVal;
            totalIterAccum = totalIterAccum + iterCount;
            
            % Any bit error triggers a frame error flag
            if berVal > 0
                totalFerAccum = totalFerAccum + 1;
            end
        end
        
        % --- Calculate Mean Performance Metrics ---
        berCurve(cIdx)  = totalBerAccum / settings.numTrials;
        ferCurve(cIdx)  = totalFerAccum / settings.numTrials;
        iterCurve(cIdx) = totalIterAccum / settings.numTrials;
        
        % Log convergence status for the current SNR node
        fprintf('    |-- C/N0: %2.1f dB-Hz | BER: %.2e | FER: %.2e | AvgIter: %.2f\n', ...
            currentCn0, berCurve(cIdx), ferCurve(cIdx), iterCurve(cIdx));
    end
    
    % --- Archive Current Algorithm Results ---
    results(aIdx).name = algoNames{aIdx};
    results(aIdx).BER  = berCurve;
    results(aIdx).FER  = ferCurve;
    results(aIdx).Iter = iterCurve;
    results(aIdx).Cn0  = cn0Range;
    
    % --- Critical Safety Mechanism: Unload Path ---
    % Forcibly remove the current algorithm path to prevent function shadowing in subsequent iterations
    rmpath(genpath(algoPath));
end

%% Data Analysis & Visualization ===========================================
if ~exist('results', 'var') || isempty(fieldnames(results))
    warning('[Error] Simulation queue is empty. No valid results generated. Check algorithm directories.');
else
    % Invoke the multi-algorithm joint plotting function from the Common library
    plotMultiAlgoResults(results, messageType, settings.maxIterations);
end
