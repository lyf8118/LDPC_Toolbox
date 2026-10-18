function plotComparisonResults(berNeural, berBaseline, settings)
% =========================================================================
% FUNCTION: plotComparisonResults
% DESCRIPTION:
%   Generates a publication-quality comparison plot for two BER curves.
%   Automatically adapts titles and filenames based on signal type.
%
% INPUTS:
%   berNeural   : [1 x N] BER vector for the Proposed Neural-EMS.
%   berBaseline : [1 x N] BER vector for the Conventional EMS (Baseline).
%   settings    : Configuration structure containing:
%                 - settings.cn0Range    : X-axis values.
%                 - settings.messageType : Signal name (e.g., 'B2b').
%                 - settings.maxIterations: For title info.
% =========================================================================

    % Extract parameters for easier access
    cn0Range = settings.cn0Range;
    sigType  = settings.messageType;
    maxIter  = settings.maxIterations;

    % Create a new figure window with a clean white background
    figure('Name', ['BER Comparison: ', sigType], 'NumberTitle', 'off', 'Color', 'w');
    
    % --- Plotting ---
    % 1. Proposed Neural-EMS (Red with Circles)
    semilogy(cn0Range, berNeural, '-o', ...
        'Color', 'r', ...               
        'LineWidth', 1.5, ...
        'MarkerSize', 7, ...
        'MarkerFaceColor', 'r', ...      % Filled marker for better visibility
        'DisplayName', 'Proposed Neural-EMS');
    
    hold on;
    
    % 2. Conventional EMS (Blue with Triangles)
    semilogy(cn0Range, berBaseline, '-^', ...
        'Color', 'b', ...
        'LineWidth', 1.5, ...
        'MarkerSize', 7, ...
        'MarkerFaceColor', 'b', ...
        'DisplayName', 'Conventional EMS');

    % --- Styling & Annotations ---
    grid on;
    box on;
    
    % Axis Labels (LaTeX interpreter for professional look)
    xlabel('Carrier-to-Noise Density Ratio, $C/N_0$ (dB-Hz)', 'Interpreter', 'latex', 'FontSize', 12);
    ylabel('Bit Error Rate (BER)', 'Interpreter', 'latex', 'FontSize', 12);
    
    % Dynamic Title based on Settings
    titleString = sprintf('Performance Comparison: %s Signal (Iter=%d)', sigType, maxIter);
    title(titleString, 'Interpreter', 'none', 'FontSize', 14, 'FontWeight', 'bold');

    % Legend
    legend('show', 'Location', 'southwest', 'FontSize', 10);

    % --- Axis Limits ---
    xlim([min(cn0Range), max(cn0Range)]);
    
    % Set Y-limit floor to 1e-6 or 1e-7 for consistency, avoid -Inf issues
    currentYLim = ylim;
    if currentYLim(1) < 1e-6
        ylim([1e-6, 1]); 
    end

    % --- Save Figure ---
    % Auto-generate filename: BER_Compare_B2b_Iter15.png
    saveFileName = sprintf('BER_Compare_%s_Iter%d', sigType, maxIter);
    
    % Save as both FIG (editable) and PNG (image)
    saveas(gcf, [saveFileName, '.fig']);
    saveas(gcf, [saveFileName, '.png']);
    
    fprintf('[-] Comparison plot saved as %s.png\n', saveFileName);
    
end