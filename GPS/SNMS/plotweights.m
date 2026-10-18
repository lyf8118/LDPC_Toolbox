%% 权重全面可视化脚本 (查看每一个活跃 Degree)
clear; clc; close all;

% 1. 设置权重文件名
filename = 'NMS_Weights_L1C_2_Final.mat';

% [修复] 从文件名自动解析 messageType，避免找不到 settings 报错
if contains(filename, 'L1C_2')
    msgTypeStr = 'L1C_2';
elseif contains(filename, 'L1C_3')
    msgTypeStr = 'L1C_3';
else
    msgTypeStr = 'Unknown';
end

if ~exist(filename, 'file')
    error('找不到文件: %s，请确认路径或先运行训练。', filename);
end
load(filename);

% 提取权重矩阵: [MaxDegree x MaxIter]
weights = neuralParams.weights;
[maxDeg, maxIter] = size(weights);

fprintf('[-] 正在分析权重矩阵 (%s)...\n', msgTypeStr);
fprintf('    最大度数 (Max Degree): %d\n', maxDeg);
fprintf('    迭代层数 (Layers):     %d\n', maxIter);

% 2. 自动筛选活跃度数 (Active Degrees)
% 原理：如果某个度数在 H 矩阵中不存在，它的梯度永远为 0，权重会一直保持在初始值 (0.8)
initialValue = 0.8;
tolerance = 1e-4; % 容差

activeDegrees = [];
for d = 1:maxDeg
    if any(abs(weights(d, :) - initialValue) > tolerance)
        activeDegrees = [activeDegrees, d];
    end
end

fprintf('[-] 检测到 %d 个活跃度数:\n', length(activeDegrees));
disp(activeDegrees);

% 3. 绘图
figure('Name', 'All Active Degrees Weights', 'Color', 'w', 'Position', [100, 100, 1000, 600]);
hold on;

colors = lines(length(activeDegrees)); 

legendEntries = {};
for i = 1:length(activeDegrees)
    d = activeDegrees(i);
    
    plot(1:maxIter, weights(d, :), '-o', ...
        'LineWidth', 2, ...
        'Color', colors(i, :), ...
        'MarkerSize', 6, ...
        'MarkerFaceColor', colors(i, :));
    
    legendEntries{end+1} = sprintf('Degree %d', d);
end

% 4. 美化图表
grid on;
xlabel('Iteration Number (Layer)', 'FontSize', 12, 'FontWeight', 'bold');
ylabel('Scaling Factor (\alpha)', 'FontSize', 12, 'FontWeight', 'bold');

% [修复] 这里直接使用解析出来的字符串 msgTypeStr，不再依赖 settings 结构体
title(['Learned Weights Evolution by Degree (' msgTypeStr ')'], 'FontSize', 14);

legend(legendEntries, 'Location', 'eastoutside', 'FontSize', 10);

% 调整 Y 轴范围
minW = min(weights(activeDegrees, :), [], 'all');
maxW = max(weights(activeDegrees, :), [], 'all');
if isempty(minW), minW=0.8; maxW=0.8; end
ylim([max(0, minW - 0.1), maxW + 0.1]);

yline(0.8, '--k', 'Baseline (0.8)', 'LineWidth', 1.5, 'Alpha', 0.5);

fprintf('[-] 绘图完成。\n');