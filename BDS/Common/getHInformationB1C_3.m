function [hIndexCell, hElementCell, hMatrix] = getHInformationB1C_3()
% =========================================================================
% FUNCTION: getHInformationB1C_3
% DESCRIPTION:
%   Generates the Parity Check Matrix (H) information specifically for the
%   GNSS B1C signal (Configuration 3).
%
%   The matrix is defined using a compressed format (Indices and Elements)
%   suitable for Non-Binary LDPC decoding.
%   - hIndexCell   : Cell array containing the column indices of non-zero 
%                    elements for each row.
%   - hElementCell : Cell array containing the non-zero GF values.
%   - hMatrix      : Full dense matrix representation of H.
%
%   Dimensions:
%     Rows (Check Nodes): 44
%     Cols (Variable Nodes): 88
%     Row Weight: 4
%
% OUTPUTS:
%   hIndexCell   : [44 x 1] Cell array of row indices.
%   hElementCell : [44 x 1] Cell array of GF element values.
%   hMatrix      : [44 x 88] Full numeric H matrix.
% =========================================================================

    % --- 1. Define Raw Column Indices (0-based from spec) ---
    hIndicesRaw = [
        14, 35, 56, 70; 1, 27, 45, 54; 2, 26, 61, 79; 12, 38, 52, 68;
        17, 39, 44, 75; 17, 43, 67, 81; 0, 37, 70, 86; 18, 28, 67, 85;
        1, 36, 71, 87; 12, 37, 57, 83; 7, 25, 51, 60;
        11, 29, 55, 73; 23, 41, 63, 87; 9, 33, 59, 77; 23, 43, 58, 77;
        9, 35, 49, 72; 22, 40, 62, 86; 5, 31, 49, 75; 0, 26, 44, 55;
        16, 38, 45, 74; 6, 31, 51, 80; 3, 27, 60, 78;
        13, 39, 53, 69; 2, 20, 46, 68; 4, 30, 48, 74; 19, 21, 63, 64;
        19, 29, 66, 84; 3, 21, 47, 69; 4, 40, 53, 84; 10, 28, 54, 72;
        8, 34, 48, 73; 15, 33, 47, 79; 14, 32, 46, 78;
        15, 34, 57, 71; 6, 24, 50, 61; 22, 42, 59, 76; 11, 25, 65, 82;
        13, 36, 56, 82; 10, 24, 64, 83; 5, 41, 52, 85; 7, 30, 50, 81;
        8, 32, 58, 76; 16, 42, 66, 80; 18, 20, 62, 65
    ];

    % Convert to 1-based indexing for MATLAB
    hIndices = hIndicesRaw + 1;
    
    % Convert indices to Cell Array format
    hIndexCell = cell(size(hIndicesRaw, 1), 1);  
    for i = 1:size(hIndicesRaw, 1)
        hIndexCell{i} = hIndices(i, :);  
    end

    % --- 2. Define GF Element Values (Non-zero entries) ---
    hElementsRaw = [
         30, 24, 1, 44; 51, 60, 35, 13; 6, 1, 45, 15; 24, 1, 44, 53; 1, 44, 53, 24;
         13, 18, 60, 1; 44, 53, 24, 35; 15, 35, 46, 56; 44, 30, 24, 1; 33, 42, 14, 5;
         45, 15, 6, 1; 24, 1, 44, 30; 18, 15, 32, 61; 45, 15, 6, 1; 44, 30, 24, 1;
         61, 47, 20, 8; 45, 15, 6, 1; 39, 36, 34, 33; 53, 24, 1, 44; 15, 6, 1, 45;
         34, 3, 55, 9; 1, 44, 30, 24; 40, 32, 61, 18; 1, 6, 1, 45; 15, 45, 15, 6; 
         34, 33, 45, 36; 53, 24, 1, 44; 24, 1, 44, 53; 44, 35, 31, 50; 1, 44, 53, 24;
         30, 24, 1, 44; 44, 35, 61, 50; 6, 1, 45, 15; 53, 24, 1, 44; 30, 24, 1, 44;
          1, 44, 53, 24; 55, 9, 34, 3; 15, 6, 1, 45; 37, 32, 52, 47; 12, 25, 36, 14;
         24, 1, 44, 30; 2, 50, 22, 14; 15, 6, 1, 45; 1, 44, 53, 24
    ];

    % Convert elements to Cell Array format
    hElementCell = cell(size(hElementsRaw, 1), 1);
    for i = 1:size(hElementsRaw, 1)
        hElementCell{i} = hElementsRaw(i, :); 
    end

    % --- 3. Reconstruct Full Dense Matrix (Ho) ---
    hMatrix = zeros(44, 88);
    for i = 1:44
        for j = 1:4
            colIndex = hIndices(i, j);
            elementVal = hElementsRaw(i, j);
            
            % Assign GF value to the specific coordinate
            hMatrix(i, colIndex) = elementVal;
        end
    end
end