%% Clean Environment  双共享权重
clear; clc; close all;
format compact;

%%  Configuration =========================================================
% -----------------------------------------------------
% [Control Switch] Set to true to TRAIN, false to LOAD weights
doTraining  = false;  
% -----------------------------------------------------

% Select Signal Type (Options: 'B1C_2', 'B1C_3', 'B2a', 'B2b')
messageType = 'B2a';

% Initialize Settings
settings = initSettings(messageType);

% Define Weight Filename dynamically
weightFileName = sprintf('neural_ems_%s_final.mat', messageType);

%%  Logic Controller ======================================================

if doTraining
    %% --- CASE A: Train New Model ---
    fprintf('>>> [MODE: TRAIN] Starting Neural EMS Training for %s <<<\n', messageType);
    
    % 1. Run Training
    neuralParams = snemsTrain(settings, settings.numEpochs, settings.cn0Range);
    
    % 2. Save Weights
    c2vWeights = neuralParams.c2vWeights;
    vnWeights  = neuralParams.vnWeights;
    save(weightFileName, 'c2vWeights', 'vnWeights');
    
    fprintf('[-] Training complete. Weights saved to: %s\n', weightFileName);

else
    %% --- CASE B: Load Pre-trained Model ---
    fprintf('>>> [MODE: INFERENCE] Loading Pre-trained Weights for %s <<<\n', messageType);
    
    if exist(weightFileName, 'file')
        % 1. Load Weights
        loadedData = load(weightFileName);
        
        % 2. Reconstruct neuralParams
        neuralParams.c2vWeights  = loadedData.c2vWeights;
        neuralParams.vnWeights   = loadedData.vnWeights;
        neuralParams.isTrainMode = false;
        
        fprintf('[-] Successfully loaded weights from: %s\n', weightFileName);
    else
        error('Weight file "%s" not found! Please set doTraining = true first.', weightFileName);
    end
end

%% Parallel Test Performance ==============================================
fprintf('\n>>> Starting Performance Testing (%s) <<<\n', messageType);

% The independent Monte Carlo frames are evaluated with parfor in snemsTest.
[berNeural, berBaseline] = snemsTest(settings, neuralParams, settings.cn0Range, settings.numTrials);

% Plot the comparison results
plotComparisonResults(berNeural, berBaseline, settings);

fprintf('>>> All tasks completed successfully.\n');
