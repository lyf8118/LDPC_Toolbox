function plotComparisonResults(berNeural, berBaseline, cn0Range, settings)
    % Create Figure
    figure('Name', ['NMS vs EMS: ', settings.messageType], 'Color', 'w');
    
    % --- Plot Baseline (Standard Scaled MS) ---
    semilogy(cn0Range, berBaseline, '--bo', ...
        'LineWidth', 1.5, ...
        'MarkerSize', 6, ...
        'DisplayName', 'Standard Scaled MS (0.8)');
    hold on;
    
    % --- Plot Neural (Neural Min-Sum) ---
    semilogy(cn0Range, berNeural, '-rx', ...
        'LineWidth', 2, ...
        'MarkerSize', 8, ...
        'MarkerFaceColor', 'r', ...
        'DisplayName', 'Neural Min-Sum (Proposed)');
    
    % --- Styling ---
    grid on;
    xlabel('Carrier-to-Noise Density Ratio, C/N_0 (dB-Hz)', 'FontSize', 12);
    ylabel('Bit Error Rate (BER)', 'FontSize', 12);
    
    titleStr = sprintf('Performance Comparison: %s Signal', settings.messageType);
    title(titleStr, 'FontSize', 14, 'FontWeight', 'bold', 'Interpreter', 'none');
    
    legend('show', 'Location', 'southwest', 'FontSize', 11);
    
    % Axis adjustments
    xlim([min(cn0Range), max(cn0Range)]);
    
    % Handle clean plots if BER drops to 0
    allBer = [berNeural(berNeural>0), berBaseline(berBaseline>0)];
    if isempty(allBer)
        ylim([1e-6, 1]); % Default range if no errors
    else
        minBer = min(allBer);
        ylim([max(1e-7, minBer/5), 1]);
    end

    fprintf('[-] Comparison plot generated.\n');
end