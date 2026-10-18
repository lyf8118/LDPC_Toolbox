function settings = initSettings(messageType)
% =========================================================================
% FUNCTION: initSettings
% DESCRIPTION:
%   Initializes simulation parameters and system configurations based on the
%   selected GNSS signal type. It sets up both common parameters (global)
%   and signal-specific parameters (LDPC matrix dimensions, integration times).
%
% INPUT:
%   messageType : String defining the target signal (e.g., 'B1C_2', 'B2b').
%
% OUTPUT:
%   settings    : Structure containing all simulation configurations.
% =========================================================================

    %% =================  Common Parameters (Global) =================
    % These parameters apply to all signal types unless overwritten.
    
    settings.simLevel           = 'SYMBOL_LEVEL'; % Direct correlator-output statistics
    settings.codeFreqBasis      = 10.23e6;  % Code frequency basis (Hz)
    settings.codeLength         = 10230;    % Code length (chips)
    
    % --- EMS Algorithm Settings ---
    settings.maxIterations      = 15;       % Maximum LDPC decoding iterations
    settings.nmEms              = 4;        % Truncation size for EMS algorithm
    
    % --- Simulation Control ---
    settings.numTrials          = 100;       % Number of Monte Carlo trials per C/N0
    settings.cn0Range           = 27:1:32;  % Default C/N0 range (dB-Hz)
    settings.messageType        = messageType; % Store current signal type tag
    settings.numEpochs          = 50;
    
    % --- Galois Field Configuration (GF(64)) ---
    settings.gfBits             = 6;        % Number of bits in GF (N_GF)
    settings.gfSize             = 64;       % Galois Field size (Q)
    settings.bitsPerSymbol      = 6;        % Bits per symbol
    
    %% ================= Signal-Specific Parameters =================
    % Configurations for matrix dimensions (H) and integration times.
    
    switch messageType
        case 'B1C_2'
            fprintf('[-] Loading configuration for signal: B1C_2\n');
            settings.dataBitTime       = 10;    % Integration time (ms)
                       
            settings.rowH              = 100;   % Check Node count (M)
            settings.colH              = 200;   % Variable Node count (N)
            settings.symbolsPerFrame   = 100;   % Information symbols per frame
    
        case 'B1C_3'
            fprintf('[-] Loading configuration for signal: B1C_3\n');
            settings.dataBitTime       = 10;    
                       
            settings.rowH              = 44;    
            settings.colH              = 88;    
            settings.symbolsPerFrame   = 44;    
            
        case 'B2a'
            fprintf('[-] Loading configuration for signal: B2a\n');
            settings.dataBitTime       = 5;    
                        
            settings.rowH              = 48;    
            settings.colH              = 96;
            settings.symbolsPerFrame   = 48;
            
        case 'B2b'
            fprintf('[-] Loading configuration for signal: B2b\n');
            settings.dataBitTime       = 1;     
            
            settings.rowH              = 81;    
            settings.colH              = 162;
            settings.symbolsPerFrame   = 81;    
            
        otherwise
            error('initSettings: Unknown messageType "%s". Options: B1C_2, B1C_3, B2a, B2b.', messageType);
    end
    
    %% =================  Pre-computation =================
    % Generate and cache the Galois Field multiplication table for efficiency.
    settings.gfMulTable = getGfTable();
    
end
