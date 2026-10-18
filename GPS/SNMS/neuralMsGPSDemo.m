%% Clean Environment
clear; clc; close all;
format compact;

%% Configuration
doTraining  = true;  
messageType = 'L1C_2'; 
weightFileName = sprintf('SNMS_SharedWeights_%s_Final.mat', messageType);

trainIterMax = 15;      
trainEpochs  = 10; 

% 训练范围：重点关注 18.0 - 20.0，Reg样本会自动补充低信噪比数据
trainCn0 = [18.0, 18.5, 19.0, 19.5, 20.0]; 

if exist('initSettings', 'file')
    settings = initSettings(messageType);
else
    settings.messageType = messageType;
    settings.maxIterations = trainIterMax;
end

%% Logic Controller
if doTraining
    fprintf('>>> [MODE: TRAIN] Starting Rational SNMS Training <<<\n');
    neuralParams = snmsTrain(messageType, trainIterMax, trainEpochs, trainCn0);
    save(weightFileName, 'neuralParams');
else
    fprintf('>>> [MODE: INFERENCE] Loading Weights <<<\n');
    load(weightFileName);
    neuralParams.isTrainMode = false;
end

%% Parallel Test Performance
testCn0    = 17:1:21;   
testTrials = 100; 

fprintf('\n>>> Starting Performance Testing <<<\n');
% The independent Monte Carlo frames are evaluated with parfor in snmsTest.
[berNeural, berBaseline, iterN, iterB] = snmsTest(settings, neuralParams, testCn0, testTrials);

%% Visualization
figure('Name', 'Final Performance');
subplot(2,1,1);
semilogy(testCn0, berBaseline, '-o', 'DisplayName', 'Standard MS'); hold on;
semilogy(testCn0, berNeural, '-s', 'LineWidth', 2, 'DisplayName', 'Neural SNMS');
grid on; legend show; ylabel('BER'); title('Bit Error Rate');

subplot(2,1,2);
plot(testCn0, iterB, '--o', 'DisplayName', 'Standard MS'); hold on;
plot(testCn0, iterN, '-s', 'LineWidth', 2, 'DisplayName', 'Neural SNMS');
grid on; legend show; ylabel('Iterations'); title('Average Iterations');
