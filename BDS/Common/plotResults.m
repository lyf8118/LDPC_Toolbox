function plotResults(berResults, ferResults, avgIterResults, settings)
% =========================================================================
% FUNCTION: plotResults
% DESCRIPTION:
%   Generates publication-quality performance plots for BDS LDPC-coded signals:
%   1. Bit Error Rate (BER) vs. C/N0
%   2. Frame Error Rate (FER) vs. C/N0
%   3. Average Decoding Iterations vs. C/N0
%
% INPUTS:
%   berResults    : [1 x N] Vector of Bit Error Rate values.
%   ferResults    : [1 x N] Vector of Frame Error Rate values.
%   avgIterResults: [1 x N] Vector of Average Decoding Iterations.
%   settings      : Configuration structure containing:
%                   - settings.cn0Range   : X-axis values (C/N0 in dB-Hz).
%                   - settings.messageType: Signal identifier (e.g., 'B2b').
%                   - settings.maxIterations: (Optional) For Y-axis limit.
%
% OUTPUTS:
%   None (Generates three figure windows).
% =========================================================================

    %% 1. Signal Identification and Labeling
    % Map internal configuration codes to formal signal names for plotting
    switch settings.messageType
        case 'B1C_2'
            signalName = 'BDS B1C Subframe 2 (B-CNAV1)';
        case 'B1C_3'
            signalName = 'BDS B1C Subframe 3 (B-CNAV1)';
        case 'B2a'
            signalName = 'BDS B2a (B-CNAV2)';
        case 'B2b'
            signalName = 'BDS B2b (B-CNAV3)';
        otherwise
            signalName = ['BDS Signal: ', settings.messageType];
    end
    
    % Common plotting parameters
    lineWidth = 1.5;
    markerSize = 6;
    xLabelStr = 'Data-component $C/N_0$ (dB-Hz)';
    
    %% 2. Figure 1: Bit Error Rate (BER) Analysis
    figure('Name', ['BER Analysis - ', settings.messageType], ...
           'NumberTitle', 'off', 'Color', 'w');
    
    semilogy(settings.cn0Range, berResults, '-bo', ...
        'LineWidth', lineWidth, ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', 'b', ...
        'DisplayName', 'Simulated BER');
    
    % Styling
    grid on; box on;
    xlabel(xLabelStr, 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Bit Error Rate (BER)', 'Interpreter', 'latex', 'FontSize', 12);
    title(['BER Performance: ', signalName], ...
          'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    legend('show', 'Location', 'southwest');
    
    % Axis adjustments
    xlim([min(settings.cn0Range), max(settings.cn0Range)]);
    if max(berResults) > 0
        ylim([max(1e-7, min(berResults(berResults>0))/10), 1]);
    else
        ylim([1e-7, 1]); 
    end
    
    %% 3. Figure 2: Frame Error Rate (FER) Analysis
    figure('Name', ['FER Analysis - ', settings.messageType], ...
           'NumberTitle', 'off', 'Color', 'w');
    
    semilogy(settings.cn0Range, ferResults, '-rs', ...
        'LineWidth', lineWidth, ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', 'r', ...
        'DisplayName', 'Simulated FER');
    
    % Styling
    grid on; box on;
    xlabel(xLabelStr, 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Frame Error Rate (FER)', 'Interpreter', 'latex', 'FontSize', 12);
    title(['FER Performance: ', signalName], ...
          'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    legend('show', 'Location', 'southwest');
    
    % Axis adjustments
    xlim([min(settings.cn0Range), max(settings.cn0Range)]);
    if max(ferResults) > 0
        ylim([max(1e-5, min(ferResults(ferResults>0))/10), 1]);
    else
        ylim([1e-5, 1]); 
    end
    
    %% 4. Figure 3: Average Iteration Analysis
    figure('Name', ['Avg Iterations - ', settings.messageType], ...
           'NumberTitle', 'off', 'Color', 'w');
    
    % Use linear plot for iterations (not log)
    plot(settings.cn0Range, avgIterResults, '-g^', ...
        'LineWidth', lineWidth, ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', 'g', ...
        'DisplayName', 'Avg. Iterations');
    
    % Styling
    grid on; box on;
    xlabel(xLabelStr, 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Average Iterations', 'Interpreter', 'latex', 'FontSize', 12);
    title(['Convergence Speed: ', signalName], ...
          'Interpreter', 'none', 'FontSize', 12, 'FontWeight', 'bold');
    legend('show', 'Location', 'northeast');
    
    % Axis adjustments
    xlim([min(settings.cn0Range), max(settings.cn0Range)]);
    % Y-axis should allow space up to maxIterations
    currentMaxIter = max(avgIterResults);
    upperLimit = max([currentMaxIter * 1.2, settings.maxIterations]); 
    ylim([0, upperLimit]);
    
end
