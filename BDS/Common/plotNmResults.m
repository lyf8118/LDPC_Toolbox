function plotNmResults(berResults, ferResults, avgIterResults, settings,algorithm)
% =========================================================================
% FUNCTION: plotNmResults (Custom Colors & Legend Fixed)
% DESCRIPTION:
%   Generates publication-quality plots. 
%   - Colors: Gold, Red, Dark Green.
%   - Legend: Auto-detects nm values if provided.
% =========================================================================

    %% 1. Signal Identification and Setup
    switch settings.messageType
        case 'B1C_2', signalName = 'BDS B1C Subframe 2 (B-CNAV1)';
        case 'B1C_3', signalName = 'BDS B1C Subframe 3 (B-CNAV1)';
        case 'B2a',   signalName = 'BDS B2a (B-CNAV2)';
        case 'B2b',   signalName = 'BDS B2b (B-CNAV3)';
    end
    

    lineColors = {[0.929, 0.694, 0.125], 'r', [0, 0.5, 0], 'b', 'm'};
    
    lineStyles = {'-o', '-s', '-^', '-d', '-<'}; 
    
    [numScenarios, ~] = size(berResults);
    
    legendLabels = arrayfun(@(x) sprintf('nm_{%s}=%d',algorithm, x), settings.nmList, 'UniformOutput', false);

    lineWidth = 1.5;
    markerSize = 7; 
    xLabelStr = 'Data-component $C/N_0$ (dB-Hz)';

    %% 2. Figure 1: Bit Error Rate (BER) Analysis [Log Scale]
    figure('Name', ['BER Analysis - ', settings.messageType], 'NumberTitle', 'off', 'Color', 'w');
    clf; 
    axBer = axes; hold on; 
    
    for i = 1:numScenarios
        semilogy(settings.cn0Range, berResults(i, :), lineStyles{mod(i-1,5)+1}, ...
            'Color', lineColors{mod(i-1,5)+1}, ... 
            'LineWidth', lineWidth, ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', lineColors{mod(i-1,5)+1}, ... 
            'DisplayName', legendLabels{i}); 
    end
    
    % Force Log Scale
    set(gca, 'YScale', 'log'); 
    
    grid on; box on;
    xlabel(xLabelStr, 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Bit Error Rate (BER)', 'Interpreter', 'latex', 'FontSize', 12);
    title(['BER Performance: ', signalName], 'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    legend(axBer, 'show', 'Location', 'southwest');
    
    % Limits
    xlim([min(settings.cn0Range), max(settings.cn0Range)]);
    minBer = min(berResults(berResults > 0)); 
    if isempty(minBer), minBer=1e-7; end
    ylim([minBer/10, 1]); 

    %% 3. Figure 2: Frame Error Rate (FER) Analysis [Log Scale]
    figure('Name', ['FER Analysis - ', settings.messageType], 'NumberTitle', 'off', 'Color', 'w');
    clf;
    axFer = axes; hold on;
    
    for i = 1:numScenarios
        semilogy(settings.cn0Range, ferResults(i, :), lineStyles{mod(i-1,5)+1}, ...
            'Color', lineColors{mod(i-1,5)+1}, ...
            'LineWidth', lineWidth, ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', 'none', ... 
            'DisplayName', legendLabels{i});
    end
    
    % Force Log Scale
    set(gca, 'YScale', 'log');
    
    grid on; box on;
    xlabel(xLabelStr, 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Frame Error Rate (FER)', 'Interpreter', 'latex', 'FontSize', 12);
    title(['FER Performance: ', signalName], 'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    legend(axFer, 'show', 'Location', 'southwest');
    
    % Limits
    xlim([min(settings.cn0Range), max(settings.cn0Range)]);
    minFer = min(ferResults(ferResults > 0));
    if isempty(minFer), minFer=1e-5; end
    ylim([minFer/10, 1]);

    %% 4. Figure 3: Average Iteration Analysis [Linear Scale]
    figure('Name', ['Avg Iterations - ', settings.messageType], 'NumberTitle', 'off', 'Color', 'w');
    clf;
    axIter = axes; hold on;
    
    for i = 1:numScenarios
        plot(settings.cn0Range, avgIterResults(i, :), lineStyles{mod(i-1,5)+1}, ...
            'Color', lineColors{mod(i-1,5)+1}, ...
            'LineWidth', lineWidth, ...
            'MarkerSize', markerSize, ...
            'MarkerFaceColor', lineColors{mod(i-1,5)+1}, ...
            'DisplayName', legendLabels{i});
    end
    
    set(gca, 'YScale', 'linear'); 
    
    grid on; box on;
    xlabel(xLabelStr, 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Average Iterations', 'Interpreter', 'latex', 'FontSize', 12);
    title(['Convergence Speed: ', signalName], 'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    legend(axIter, 'show', 'Location', 'northeast');
    
    % Limits
    xlim([min(settings.cn0Range), max(settings.cn0Range)]);
    ylim([0, settings.maxIterations]);

end
