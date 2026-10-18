%% Clean Environment
clear; clc; close all;
format compact;

%%  Configuration =========================================================
% -----------------------------------------------------
% [Control Switch] Set to true to TRAIN, false to LOAD weights
doTraining  = false;  
% -----------------------------------------------------

messageType = 'L1C_2';

% Initialize Settings
settings = initSettings(messageType);
weightFileName = sprintf('NMS_Weights_%s_Final.mat', messageType);

% Setup Training Parameters
trainIterMax = 15;          
trainEpochs  = 30;          

basic_range = 15:1:22;
focus_range = repmat([18.5, 19.0, 19.5, 20.0], 1, 5); 
trainCn0 = [basic_range, focus_range];

% Setup Testing Parameters
testCn0      = 15:1:20;   
testTrials   = 1000;       

%%  Logic Controller ======================================================
if doTraining
    %% --- CASE A: Train New Model ---
    fprintf('>>> [MODE: TRAIN] Starting Neural Min-Sum Training for %s <<<\n', messageType);
    fprintf('    Layers: %d, Epochs: %d\n', trainIterMax, trainEpochs);
    
    % 1. Run Training
    neuralParams = nmsTrain(messageType, trainIterMax, trainEpochs, trainCn0);
    
    % 2. Save Weights
    save(weightFileName, 'neuralParams');
    fprintf('[-] Training complete. Weights saved to: %s\n', weightFileName);
    
else
    %% --- CASE B: Load Pre-trained Model ---
    fprintf('>>> [MODE: INFERENCE] Loading Pre-trained Weights for %s <<<\n', messageType);
    
    if exist(weightFileName, 'file')
        loadedData = load(weightFileName);
        
        if isfield(loadedData, 'neuralParams')
            neuralParams = loadedData.neuralParams;
        elseif isfield(loadedData, 'weights')
            neuralParams.weights = loadedData.weights;
        else
            error('Invalid weight file format.');
        end
        
        neuralParams.isTrainMode = false;
        fprintf('[-] Successfully loaded weights from: %s\n', weightFileName);
    else
        error('Weight file "%s" not found! Please set doTraining = true first.', weightFileName);
    end
end

%% Parallel Test Performance ==============================================
fprintf('\n>>> Starting Performance Testing (%s) <<<\n', messageType);
% The independent Monte Carlo frames are evaluated with parfor in nmsTest.
[berNeural, berBaseline] = nmsTest(settings, neuralParams, testCn0, testTrials);

%% Visualization ==========================================================
% plotComparisonResults(berNeural, berBaseline, testCn0, settings);
fprintf('>>> All tasks completed successfully.\n');

