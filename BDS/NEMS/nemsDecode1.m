function [decodedCodeword, realIter] = nemsDecode1(llrMatrix, settings, neuralParams)
% =========================================================================
% 函数：nemsDecode1 (神经EMS译码器)
% 描述：利用预训练权重进行推理，支持 B1C/B2a/B2b 信号。
% =========================================================================
    
    %% 初始化与图构建
    % 根据信号类型加载 H 矩阵信息
    switch settings.messageType
        case 'B1C_2', [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_2();
        case 'B1C_3', [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_3();
        case 'B2a',   [hIndexCell, hElementCell, hMatrix] = getHInformationB2a();
        case 'B2b',   [hIndexCell, hElementCell, hMatrix] = getHInformationB2b();
    end
    
    [rowIndices, colIndices, edgeWeights, numEdges] = getGraphEdges(hIndexCell, hElementCell);
    
    % 预计算相邻列表
    cnConnections = cell(settings.rowH, 1);
    for j = 1:settings.rowH
        cnConnections{j} = find(rowIndices == j);
    end
    
    vnConnections = cell(settings.colH, 1);
    for i = 1:settings.colH
        vnConnections{i} = find(colIndices == i);
    end
    
    % 转换权重精度
    c2vWeights = single(neuralParams.c2vWeights);
    vnWeights  = single(neuralParams.vnWeights);
    intrinsicLlr = single(llrMatrix);
    
    %% 内存分配与初始硬判决
    varToCheckMsg    = zeros(numEdges, settings.gfSize, 'single');
    checkToVarMsg    = zeros(numEdges, settings.gfSize, 'single');
    
    [~, minIndices] = min(intrinsicLlr, [], 2);
    decodedCodeword = uint8(minIndices - 1)';
    
    % 初始化 V2C 消息
    for i = 1:numEdges
        varToCheckMsg(i, :) = permuteV2C(edgeWeights(i), intrinsicLlr(colIndices(i), :), settings.gfMulTable);
    end
    realIter = settings.maxIterations;
    
    %% 迭代译码循环
    for iter = 1:settings.maxIterations
        
        % 当前迭代权重索引
        itC2V = min(iter, size(c2vWeights, 3));
        itVN  = min(iter, size(vnWeights, 3));
        
        % 伴随式校验 (提前终止)
        syndrome = gf(double(decodedCodeword), settings.gfBits) * gf(hMatrix.', settings.gfBits);
        if all(syndrome == 0)
            realIter = iter;
            break;
        end
        
        % --- 校验节点更新 (CNU) ---
        for j = 1:settings.rowH
            connectedEdges = cnConnections{j};
            
            for k = 1:length(connectedEdges)
                targetEdgeIdx = connectedEdges(k);
                aggregatedLlr = [];
                
                % 排除自身的 LLR 聚合
                sourceEdges = connectedEdges(connectedEdges ~= targetEdgeIdx);
                for m = 1:length(sourceEdges)
                    aggregatedLlr = extMinSum(aggregatedLlr, varToCheckMsg(sourceEdges(m), :), settings);
                end
                
                % 归一化与置换回变量节点域
                aggregatedLlr = aggregatedLlr - min(aggregatedLlr);
                rawMsg = permuteC2V(edgeWeights(targetEdgeIdx), aggregatedLlr, settings.gfMulTable);
                
                % [神经步] 稀疏优化计算
                w = c2vWeights(targetEdgeIdx, 1, itC2V);
                satVal = max(rawMsg); 
                satOut = 0.5 * w * satVal + 0.5 * tanh(w * satVal);
                
                % 默认填充饱和输出，仅对有效非饱和值重算
                edgeOut = ones(1, settings.gfSize, 'single') * satOut;
                validIndices = find(rawMsg < satVal - 1e-5);
                validVals = rawMsg(validIndices);
                edgeOut(validIndices) = 0.5 * w * validVals + 0.5 * tanh(w * validVals);
                
                checkToVarMsg(targetEdgeIdx, :) = edgeOut;
            end
        end
        
        % --- 变量节点更新 (VNU) ---
        for i = 1:settings.colH
            connectedEdges = vnConnections{i};
            
            % 计算总 LLR 与神经阻尼权重
            totalLlr = intrinsicLlr(i, :) + sum(checkToVarMsg(connectedEdges, :), 1);
            beta = vnWeights(1, 1, itVN);
            
            % 后验 LLR 与硬判决更新
            posteriorLlr = intrinsicLlr(i, :) + beta * (totalLlr - intrinsicLlr(i, :));
            posteriorLlr = posteriorLlr - min(posteriorLlr);
            [~, minIdx] = min(posteriorLlr);
            decodedCodeword(i) = minIdx - 1;
            
            % 生成外显 V2C 消息
            for k = 1:length(connectedEdges)
                edgeIdx = connectedEdges(k);
                extrinsicMsg = posteriorLlr - checkToVarMsg(edgeIdx, :);
                varToCheckMsg(edgeIdx, :) = permuteV2C(edgeWeights(edgeIdx), extrinsicMsg - min(extrinsicMsg), settings.gfMulTable);
            end
        end
    end
    
    decodedCodeword = double(decodedCodeword);
end
