% =========================================================================
% FUNCTION: plotMultiAlgoResults
% DESCRIPTION:
%   Generates high-resolution, IEEE-standard academic plots to visualize 
%   and compare the performance of multiple LDPC decoding algorithms. 
%   It outputs independent figures for Bit Error Rate (BER), Frame Error 
%   Rate (FER), and Average Iterations. The function includes a built-in 
%   LaTeX character escaping mechanism to ensure precise rendering of 
%   legends and coordinate axes.
%
% INPUTS:
%   results       : [Struct Array] Contains simulation results for each 
%                   algorithm. Required fields: name, BER, FER, Iter, Cn0.
%   messageType   : [String] Target signal type identifier (e.g., 'L1C_2').
%   maxIterations : [Integer] The predefined maximum iteration ceiling 
%                   configured for the LDPC decoders.
%
% OUTPUTS:
%                   Generates and displays Figure 1 (BER Waterfall), 
%                   Figure 2 (FER Waterfall), and Figure 3 (Iterations).
% =========================================================================

function plotMultiAlgoResults(results, messageType, maxIterations)

    % --- LaTeX Parsing Engine Protection: Character Escaping ---
    msgTypeStr = strrep(messageType, '_', '\_');
    for k = 1:length(results)
        results(k).displayName = strrep(results(k).name, '_', '\_');
    end

    markers    = {'o', 's', '^', 'd', 'v', '>', '<', 'p', 'h'};
    lineStyles = {'-', '--', '-.', '-'};
    colors     = lines(length(results)); 
    
    lineWidth  = 1.5;
    markerSize = 7;
    fontSize   = 12;
    fontName   = 'Times New Roman';

   
    %% Figure 1: Bit Error Rate (BER) Waterfall Curve======================

    figure('Name', ['BER Performance: ' messageType], 'Color', 'w');
    ax1 = gca;
    hold(ax1, 'on'); grid(ax1, 'on'); grid(ax1, 'minor');
    
    xlabel('$C/N_0$ (dB-Hz)', 'Interpreter', 'latex');
    ylabel('Bit Error Rate (BER)', 'Interpreter', 'latex');
    title(['BER Performance (', msgTypeStr, ')'], 'Interpreter', 'latex');
    set(ax1, 'YScale', 'log', 'FontName', fontName, 'FontSize', fontSize);
    
    for i = 1:length(results)
        x = results(i).Cn0;
        y = results(i).BER;
        
        % Data Truncation: Logarithmic axes cannot render non-positive values. 
        % Assign NaN to break the line and prevent rendering anomalies.
        y(y <= 0) = NaN; 
        
        mk = markers{mod(i-1, length(markers)) + 1};
        ls = lineStyles{mod(i-1, length(lineStyles)) + 1};
        c  = colors(i, :);
        
        semilogy(ax1, x, y, ...
            'LineStyle', ls, 'LineWidth', lineWidth, 'Color', c, ...
            'Marker', mk, 'MarkerSize', markerSize, 'MarkerFaceColor', c, ...
            'DisplayName', results(i).displayName);
    end
    ylim([1e-6 1]); 
    legend(ax1, 'show', 'Interpreter', 'latex', 'Location', 'best');

    %% Figure 2: Frame Error Rate (FER) Waterfall Curve====================
    figure('Name', ['FER Performance: ' messageType], 'Color', 'w');
    ax2 = gca;
    hold(ax2, 'on'); grid(ax2, 'on'); grid(ax2, 'minor');
    
    xlabel('$C/N_0$ (dB-Hz)', 'Interpreter', 'latex');
    ylabel('Frame Error Rate (FER)', 'Interpreter', 'latex');
    title(['FER Performance (', msgTypeStr, ')'], 'Interpreter', 'latex');
    set(ax2, 'YScale', 'log', 'FontName', fontName, 'FontSize', fontSize);
    
    for i = 1:length(results)
        x = results(i).Cn0;
        y = results(i).FER;
        y(y <= 0) = NaN; % Zero-value truncation handling
        
        mk = markers{mod(i-1, length(markers)) + 1};
        ls = lineStyles{mod(i-1, length(lineStyles)) + 1};
        c  = colors(i, :);
        
        % Visual Optimization: Utilize hollow markers (MarkerFaceColor='w') to 
        % effectively distinguish from the solid markers used in the BER curves.
        semilogy(ax2, x, y, ...
            'LineStyle', ls, 'LineWidth', lineWidth, 'Color', c, ...
            'Marker', mk, 'MarkerSize', markerSize, 'MarkerFaceColor', 'w', ...
            'DisplayName', results(i).displayName);
    end
    ylim([1e-4 1]);
    legend(ax2, 'show', 'Interpreter', 'latex', 'Location', 'best');

   
    %% Figure 3: Average Iterations Convergence Trend======================

    figure('Name', ['Iter Performance: ' messageType], 'Color', 'w');
    ax3 = gca;
    hold(ax3, 'on'); grid(ax3, 'on'); grid(ax3, 'minor');
    
    xlabel('$C/N_0$ (dB-Hz)', 'Interpreter', 'latex');
    ylabel('Average Iterations', 'Interpreter', 'latex');
    title(['Average Iterations (', msgTypeStr, ')'], 'Interpreter', 'latex');
    set(ax3, 'YScale', 'linear', 'FontName', fontName, 'FontSize', fontSize);
    
    for i = 1:length(results)
        x = results(i).Cn0;
        y = results(i).Iter;
        
        mk = markers{mod(i-1, length(markers)) + 1};
        ls = lineStyles{mod(i-1, length(lineStyles)) + 1};
        c  = colors(i, :);
        
        plot(ax3, x, y, ...
            'LineStyle', ls, 'LineWidth', lineWidth, 'Color', c, ...
            'Marker', mk, 'MarkerSize', markerSize, 'MarkerFaceColor', c, ...
            'DisplayName', results(i).displayName);
    end
    
    % Indicate algorithm physical limit threshold (Max Iteration asymptote)
    yline(ax3, maxIterations, '--k', 'Max Iter', ...
        'LabelHorizontalAlignment', 'left', 'Interpreter', 'latex');
    ylim([0 maxIterations + 5]);
    legend(ax3, 'show', 'Interpreter', 'latex', 'Location', 'best');
    
    drawnow;
end