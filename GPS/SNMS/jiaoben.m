%% 权重可视化脚本
clear; clc;
% 加载你刚才训练好的文件
load('NMS_Weights_L1C_2_Final.mat'); 

weights = neuralParams.weights; % [MaxDegree x MaxIter]
[maxDeg, maxIter] = size(weights);

figure('Color', 'w');
hold on;
colors = parula(maxDeg);

% 并不是所有度数都存在，我们只画存在的度数
% 对于 L1C，通常存在的度数可能是 4, 5, 10 等（取决于具体矩阵）
validDegrees = find(weights(:,1) ~= 0.8 & weights(:,end) ~= 0.8); 
% 或者简单的，画出变化最大的几行
if isempty(validDegrees), validDegrees = 1:maxDeg; end

legendStr = {};
for d = validDegrees'
    plot(1:maxIter, weights(d, :), '-o', 'LineWidth', 2, 'Color', colors(d,:));
    legendStr{end+1} = sprintf('Check Node Degree %d', d);
end

grid on;
xlabel('Iteration Number');
ylabel('Weight Value (\alpha)');
title('Learned Weights vs. Iteration (Type-3 NMS)');
legend(legendStr, 'Location', 'best');
ylim([0.2, 1.2]); % 权重通常在这个范围