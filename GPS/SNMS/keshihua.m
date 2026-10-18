%% Clean Environment
clear; clc; close all;

%% 1. 加载权重文件
filename = 'NMS_Weights_L1C_2_Final.mat';

if exist(filename, 'file')
    fprintf('[-] 正在加载权重文件: %s ...\n', filename);
    data = load(filename);
    
    % 兼容不同的保存结构 (直接变量 或 neuralParams结构体)
    if isfield(data, 'neuralParams')
        c2vWeights = data.neuralParams.c2vWeights;
        vnWeights  = data.neuralParams.vnWeights;
    elseif isfield(data, 'c2vWeights')
        c2vWeights = data.c2vWeights;
        vnWeights  = data.vnWeights;
    else
        error('无法在文件中找到 c2vWeights 或 neuralParams 变量');
    end
else
    error('文件 %s 不存在，请先运行训练脚本。', filename);
end

%% 2. 数据预处理
% 获取维度信息: [边数 x 1 x 迭代次数]
[numEdges, ~, numLayers] = size(c2vWeights);

% 提取 Beta (VN Weights): 变为 [1 x Layers] 向量
betaVec = squeeze(vnWeights); 

% 提取 Alpha (C2V Weights) 的统计信息
% meanAlpha: 每一层的平均边权重
% minAlpha / maxAlpha: 每一层的最小/最大权重
meanAlpha = squeeze(mean(c2vWeights, 1)); 
minAlpha  = squeeze(min(c2vWeights, [], 1));
maxAlpha  = squeeze(max(c2vWeights, [], 1));

fprintf('[-] 加载成功: 共 %d 层 (Iterations), 每层 %d 条边 (Edges)\n', numLayers, numEdges);

%% 3. 可视化分析
figure('Name', 'Neural Min-Sum Weights Analysis', 'Color', 'w', 'Position', [100, 100, 1200, 600]);

% --- 子图 1: Beta (VN Update Weights) 随迭代次数的变化 ---
subplot(2, 2, 1);
plot(1:numLayers, betaVec, '-bo', 'LineWidth', 2, 'MarkerFaceColor', 'b');
grid on;
xlabel('Iteration (Layer)');
ylabel('Beta Value (\beta)');
title('Evolution of VN Weights (\beta)');
xlim([1, numLayers]);
% 在点上标记数值
for i = 1:numLayers
    text(i, betaVec(i), sprintf('%.2f', betaVec(i)), ...
        'VerticalAlignment', 'bottom', 'HorizontalAlignment', 'center', 'FontSize', 8);
end

% --- 子图 2: C2V Alpha (Edge Weights) 的均值变化 ---
subplot(2, 2, 2);
plot(1:numLayers, meanAlpha, '-r', 'LineWidth', 2);
hold on;
% 绘制范围 (Min-Max 阴影或虚线)
plot(1:numLayers, minAlpha, '--r', 'LineWidth', 0.5);
plot(1:numLayers, maxAlpha, '--r', 'LineWidth', 0.5);
grid on;
xlabel('Iteration (Layer)');
ylabel('C2V Weight (\alpha)');
title('Evolution of C2V Edge Weights (\alpha)');
legend('Mean \alpha', 'Range (Min/Max)', 'Location', 'best');
xlim([1, numLayers]);

% --- 子图 3: 最后一层的 C2V 权重直方图 ---
subplot(2, 2, [3, 4]); % 占据下方整行
finalLayerWeights = c2vWeights(:, 1, end);
histogram(finalLayerWeights, 50, 'FaceColor', [0.2, 0.6, 0.5]);
grid on;
xlabel('Weight Value');
ylabel('Frequency (Count)');
title(sprintf('Distribution of Edge Weights at Final Layer (Iter %d)', numLayers));
subtitle(sprintf('Mean: %.4f, Std: %.4f', mean(finalLayerWeights), std(finalLayerWeights)));

%% 4. 打印数值表格 (Beta)
fprintf('\n=== Beta (VN Weights) Values ===\n');
fprintf('| %-6s | %-10s |\n', 'Iter', 'Beta');
fprintf('|--------|------------|\n');
for i = 1:numLayers
    fprintf('| %-6d | %-10.4f |\n', i, betaVec(i));
end

fprintf('\n=== C2V (Edge Weights) Summary (Final Layer) ===\n');
fprintf('Mean: %.4f\n', meanAlpha(end));
fprintf('Min:  %.4f\n', minAlpha(end));
fprintf('Max:  %.4f\n', maxAlpha(end));
fprintf('Std:  %.4f\n', std(finalLayerWeights));