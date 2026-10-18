function plotResults(berResults, ferResults, iterResults, settings)
% =========================================================================
% FUNCTION: plotResults
% DESCRIPTION:
%   Generates publication-quality performance plots for GPS L1C LDPC decoding.
%   The function produces three separate figures:
%     1. Bit Error Rate (BER) vs. C/N0 (Logarithmic scale)
%     2. Frame Error Rate (FER) vs. C/N0 (Logarithmic scale)
%     3. Average Iterations vs. C/N0 (Linear scale)
%
% INPUTS:
%   berResults  : [1 x N] Vector of Bit Error Rates.
%   ferResults  : [1 x N] Vector of Frame Error Rates.
%   iterResults : [1 x N] Vector of average decoding iterations.
%   settings    : Configuration structure containing:
%                 - settings.cn0Range : Vector of C/N0 values (dB-Hz).
%                 - settings.messageType : String (e.g., 'L1C_2', 'L1C').
%                 - settings.maxIterations : (Optional) Max iteration limit.
%
% OUTPUTS:
%   None (Generates figure windows directly).
%
% AUTHOR:
%   Graduate Student (Satellite Receiver Research)
% =========================================================================

    %% 1. General Configuration and Pre-processing
    % Define standard plotting aesthetics for academic publications
    fontName      = 'Times New Roman';
    fontSizeAxis  = 12;
    fontSizeTitle = 13;
    lineWidth     = 1.5;
    markerSize    = 7;
    
    % Pre-process data: Replace zero values with NaN to break the logarithmic 
    % curves in the waterfall region (standard convention).
    berPlotData = berResults;
    berPlotData(berPlotData <= 0) = NaN;
    
    ferPlotData = ferResults;
    ferPlotData(ferPlotData <= 0) = NaN;
    
    % Determine titles and legend labels based on signal type
    switch settings.messageType
        case 'L1C_2'
            titleStr      = 'GPS L1C Subframe 2 (CNAV-2)';
            legendStrBer  = 'BER (L1C_{SF2})';
            legendStrFer  = 'FER (L1C_{SF2})';
            legendStrIter = 'Avg. Iter (L1C_{SF2})';
        case 'L1C_3'
            titleStr      = 'GPS L1C Subframe 3 (CNAV-2)';
            legendStrBer  = 'BER (L1C_{SF3})';
            legendStrFer  = 'FER (L1C_{SF3})';
            legendStrIter = 'Avg. Iter (L1C_{SF3})';
        otherwise
            titleStr      = ['GPS L1C Signal: ', settings.messageType];
            legendStrBer  = ['BER (', settings.messageType, ')'];
            legendStrFer  = ['FER (', settings.messageType, ')'];
            legendStrIter = ['Avg. Iter (', settings.messageType, ')'];
    end
    
    % LaTeX string for the X-axis label
    xLabelStr = 'Carrier-to-Noise Density Ratio, $C/N_0$ (dB-Hz)';
    
    %% 2. Figure 1: Bit Error Rate (BER) Analysis
    figure('Name', ['BER Analysis - ', settings.messageType], 'Color', 'w');
    ax1 = gca;
    
    % Plot BER curve using semi-logarithmic scale
    semilogy(ax1, settings.cn0Range, berPlotData, '-bo', ...
        'LineWidth', lineWidth, ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', 'b', ...
        'DisplayName', legendStrBer);
    
    % Apply axis formatting
    grid(ax1, 'on'); grid(ax1, 'minor'); box(ax1, 'on');
    xlabel(ax1, xLabelStr, 'Interpreter', 'latex', 'FontSize', fontSizeAxis, 'FontName', fontName);
    ylabel(ax1, 'Bit Error Rate (BER)', 'Interpreter', 'latex', 'FontSize', fontSizeAxis, 'FontName', fontName);
    title(ax1, ['BER Performance: ', titleStr], 'Interpreter', 'none', 'FontSize', fontSizeTitle, 'FontName', fontName);
    legend(ax1, 'show', 'Location', 'southwest', 'FontSize', 10, 'Interpreter', 'tex');
    
    % Set axis limits
    xlim(ax1, [min(settings.cn0Range), max(settings.cn0Range)]);
    ylim(ax1, [1e-6 1]); % Standard lower limit for BER plots
    
    %% 3. Figure 2: Frame Error Rate (FER) Analysis
    figure('Name', ['FER Analysis - ', settings.messageType], 'Color', 'w');
    ax2 = gca;
    
    % Plot FER curve using semi-logarithmic scale
    semilogy(ax2, settings.cn0Range, ferPlotData, '-rs', ...
        'LineWidth', lineWidth, ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', 'r', ...
        'DisplayName', legendStrFer);
    
    % Apply axis formatting
    grid(ax2, 'on'); grid(ax2, 'minor'); box(ax2, 'on');
    xlabel(ax2, xLabelStr, 'Interpreter', 'latex', 'FontSize', fontSizeAxis, 'FontName', fontName);
    ylabel(ax2, 'Frame Error Rate (FER)', 'Interpreter', 'latex', 'FontSize', fontSizeAxis, 'FontName', fontName);
    title(ax2, ['FER Performance: ', titleStr], 'Interpreter', 'none', 'FontSize', fontSizeTitle, 'FontName', fontName);
    legend(ax2, 'show', 'Location', 'southwest', 'FontSize', 10, 'Interpreter', 'tex');
    
    % Set axis limits
    xlim(ax2, [min(settings.cn0Range), max(settings.cn0Range)]);
    ylim(ax2, [1e-5 1]); % FER is typically higher than BER
    
    %% 4. Figure 3: Average Iteration Analysis
    figure('Name', ['Iter Analysis - ', settings.messageType], 'Color', 'w');
    ax3 = gca;
    hold(ax3, 'on');
    
    % Plot Average Iterations (Linear scale)
    plot(ax3, settings.cn0Range, iterResults, '-g^', ...
        'LineWidth', lineWidth, ...
        'MarkerSize', markerSize, ...
        'MarkerFaceColor', 'g', ...
        'DisplayName', legendStrIter);
    
    % Add a reference line for Maximum Iterations (if available in settings)
    if isfield(settings, 'maxIterations')
        yline(ax3, settings.maxIterations, '--k', 'Max Iter Limit', ...
            'LineWidth', 1.2, ...
            'LabelHorizontalAlignment', 'left', ...
            'FontSize', 10, ...
            'FontName', fontName, ...
            'Interpreter', 'latex', ...
            'DisplayName', 'Iteration Limit');
        upperIterLim = settings.maxIterations + 2;
    else
        upperIterLim = max(iterResults) * 1.2;
    end
    
    % Apply axis formatting
    grid(ax3, 'on'); grid(ax3, 'minor'); box(ax3, 'on');
    xlabel(ax3, xLabelStr, 'Interpreter', 'latex', 'FontSize', fontSizeAxis, 'FontName', fontName);
    ylabel(ax3, 'Average Iterations', 'Interpreter', 'latex', 'FontSize', fontSizeAxis, 'FontName', fontName);
    title(ax3, ['Iteration Statistics: ', titleStr], 'Interpreter', 'none', 'FontSize', fontSizeTitle, 'FontName', fontName);
    legend(ax3, 'show', 'Location', 'northeast', 'FontSize', 10, 'Interpreter', 'tex');
    
    % Set axis limits
    xlim(ax3, [min(settings.cn0Range), max(settings.cn0Range)]);
    ylim(ax3, [0, upperIterLim]); % Linear scale starting from 0
    
    % Force immediate graphical update
    drawnow;
    
end