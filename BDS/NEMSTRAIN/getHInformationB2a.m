function [hIndexCell, hElementCell, hMatrix] = getHInformationB2a()
% =========================================================================
% FUNCTION: getHInformationB2a
% DESCRIPTION:
%   Generates the Parity Check Matrix (H) information specifically for the
%   GNSS B2a signal.
%
%   The matrix is defined using a compressed format (Indices and Elements)
%   suitable for Non-Binary LDPC decoding.
%   - hIndexCell   : Cell array containing the column indices of non-zero 
%                    elements for each row.
%   - hElementCell : Cell array containing the non-zero GF values.
%   - hMatrix      : Full dense matrix representation of H.
%
%   Dimensions:
%     Rows (Check Nodes): 48
%     Cols (Variable Nodes): 96
%     Row Weight: 4
%
% OUTPUTS:
%   hIndexCell   : [48 x 1] Cell array of row indices.
%   hElementCell : [48 x 1] Cell array of GF element values.
%   hMatrix      : [48 x 96] Full numeric H matrix.
% =========================================================================

    % --- 1. Define Raw Column Indices (0-based from spec) ---
    hIndicesRaw = [...
        19 46 49 76; 22 41 68 94; 8 40 60 87; 5 38 70 89; 23 37 58 83; 6 30 54 76; 1 25 49 79; 8 36 51 84; 11 33 59 81; 16 31 65 73; 21 42 75 92; 4 39 71 88; ...
        5 29 53 71; 20 44 54 75; 15 26 66 81; 16 34 64 92; 15 43 56 91; 14 27 67 80; 12 27 69 79; 3 45 56 86; 20 43 74 93; 4 28 52 70; 7 31 55 77; 13 44 68 78; ...
        17 30 64 72; 9 41 61 86; 19 24 67 95; 21 45 55 74; 18 47 48 77; 17 47 65 93; 18 35 66 94; 0 29 62 85; 13 32 63 91; 1 28 63 84; 9 37 50 85; 3 27 51 73; ...
        22 36 59 82; 6 47 60 89; 2 26 50 72; 0 24 48 78; 14 42 57 90; 7 46 61 88; 23 40 69 95; 2 39 57 87; 11 35 52 83; 12 33 62 90; 10 34 53 82; 10 32 58 80];

    % Convert to 1-based indexing for MATLAB
    hIndices = hIndicesRaw + 1;
    
    % Convert indices to Cell Array format
    hIndexCell = cell(size(hIndicesRaw, 1), 1);  
    for i = 1:size(hIndicesRaw, 1)
        hIndexCell{i} = hIndices(i, :); 
    end

    % --- 2. Define GF Element Values (Non-zero entries) ---
    hElementsRaw = [...
        1 45 15 6; 18 15 32 61; 24 1 44 53; 44 53 24 1; 45 15 6 1; 32 61 18 40; 30 24 1 44; 24 1 44 53; 1 45 15 6; 33 45 36 34; 44 35 31 50; 24 1 44 30; ...
        1 44 53 24; 3 55 9 34; 30 24 1 44; 39 36 34 33; 6 1 45 15; 1 45 15 6; 15 46 45 44; 15 6 1 45; 44 53 24 1; 6 1 45 15; 26 27 37 5; 24 1 44 30; ...
        45 15 6 1; 35 31 50 44; 32 42 47 37; 44 53 24 1; 24 1 44 53; 22 14 2 50; 45 15 6 1; 53 24 1 44; 57 25 9 41; 6 1 45 15; 24 1 44 30; 1 44 53 24; ...
        30 24 1 44; 45 15 6 1; 6 1 45 15; 44 53 24 1; 9 41 57 58; 24 1 44 30; 1 44 30 24; 7 38 23 54; 35 13 51 60; 6 1 45 15; 33 42 14 5; 1 44 30 24];

    % Convert elements to Cell Array format
    hElementCell = cell(size(hElementsRaw, 1), 1);
    for i = 1:size(hElementsRaw, 1)
        hElementCell{i} = hElementsRaw(i, :); 
    end

    % --- 3. Reconstruct Full Dense Matrix (Ho) ---
    hMatrix = zeros(48, 96);
    for i = 1:48
        for j = 1:4
            colIndex = hIndices(i, j);
            elementVal = hElementsRaw(i, j);
            
            % Assign GF value to the specific coordinate
            hMatrix(i, colIndex) = elementVal;
        end
    end
end