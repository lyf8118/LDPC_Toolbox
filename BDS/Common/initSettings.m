function settings = initSettings(messageType,simLevel)
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
    
    settings.codeLength         = 10230;    % Code length (chips)
    settings.gwnAmp             = 40;       % Gaussian White Noise amplitude scaling
    settings.fileType           = 1;        % Real IF only
    settings.FeOrder            = 128;      % Even low-pass FIR order
    settings.waveformChunkSamples = 1e6;    % Max samples held per streamed chunk
    
    % --- EMS Algorithm Settings ---
    settings.maxIterations      = 15;       % Maximum LDPC decoding iterations
    settings.nmEms              = 4;        % Truncation size for EMS algorithm
    settings.alpha              = 0.8;      % settings.alpha = 1.0->EMS  settings.alpha = 0.8->Normalized EMS
    settings.offset             = 0;      % settings.offset = 0.5;->Offset EMS  settings.offset = 0 -> EMS   

    % --- Simulation Control ---
    settings.numTrials          = 1000;     % Number of Monte Carlo trials per C/N0
    settings.cn0Range           = 16:1:22;  % Default C/N0 range (dB-Hz)
    settings.messageType        = messageType; % Store current signal type tag
    settings.simLevel           = simLevel;
    settings.cn0Reference       = 'DATA_COMPONENT';
    % messageType selects the physical data-channel modulation.  Keep the
    % legacy option only for controlled regression with the former
    % BPSK-equivalent waveform.
    settings.waveformMode       = 'SIGNAL_SPECIFIC'; % or 'BPSK_EQUIVALENT'
    settings.signalComponent    = 'DATA';
    settings.prn                = 1;        % B1C/B2a data-component PRN number

    % --- Galois Field Configuration (GF(64)) ---
    settings.gfBits             = 6;        % Number of bits in GF (N_GF)
    settings.gfSize             = 64;       % Galois Field size (Q)
    settings.bitsPerSymbol      = 6;        % Bits per symbol
    
    %% ================= Signal-Specific Parameters =================
    % Configurations for matrix dimensions (H) and integration times.
    
    switch messageType
        case 'B1C_2'
            fprintf('[-] Loading configuration for signal: B1C_2\n');
            settings.intermediateFreq   = 4e6;
            settings.FeBandwidth       = 5e6;
            settings.samplingFreq       = 16e6;
            settings.signalName          = 'B1C';
            settings.modulationType      = 'BOC11';
            settings.codeFreqBasis       = 1.023e6;
            settings.subcarrierFreq      = 1.023e6;
            settings.codePeriod          = 10e-3;
            settings.codePeriodsPerBit   = 1;
            settings.dataBitTime       = 10;    % Integration time (ms)
                       
            settings.rowH              = 100;   % Check Node count (M)
            settings.colH              = 200;   % Variable Node count (N)
            settings.symbolsPerFrame   = 100;   % Information symbols per frame
    
        case 'B1C_3'
            fprintf('[-] Loading configuration for signal: B1C_3\n');
            settings.intermediateFreq   = 4e6;
            settings.FeBandwidth       = 5e6;
            settings.samplingFreq       = 16e6;
            settings.signalName          = 'B1C';
            settings.modulationType      = 'BOC11';
            settings.codeFreqBasis       = 1.023e6;
            settings.subcarrierFreq      = 1.023e6;
            settings.codePeriod          = 10e-3;
            settings.codePeriodsPerBit   = 1;
            settings.dataBitTime       = 10;    
                       
            settings.rowH              = 44;    
            settings.colH              = 88;    
            settings.symbolsPerFrame   = 44;    
            
        case 'B2a'
            fprintf('[-] Loading configuration for signal: B2a\n');
            settings.intermediateFreq   = 15e6;
            settings.FeBandwidth       = 25e6;
            settings.samplingFreq       = 60e6;
            settings.signalName          = 'B2a';
            settings.modulationType      = 'BPSK10';
            settings.codeFreqBasis       = 10.23e6;
            settings.subcarrierFreq      = 0;
            settings.codePeriod          = 1e-3;
            settings.codePeriodsPerBit   = 5;
            settings.dataBitTime       = 5;    
                        
            settings.rowH              = 48;    
            settings.colH              = 96;
            settings.symbolsPerFrame   = 48;
            
        case 'B2b'
            fprintf('[-] Loading configuration for signal: B2b\n');
            settings.intermediateFreq   = 15e6;
            settings.FeBandwidth       = 25e6;
            settings.samplingFreq       = 60e6;
            settings.signalName          = 'B2b';
            settings.signalComponent     = 'I';
            settings.prn                 = 6; % First public-service B2b-I PRN
            settings.modulationType      = 'BPSK10';
            settings.codeFreqBasis       = 10.23e6;
            settings.subcarrierFreq      = 0;
            settings.codePeriod          = 1e-3;
            settings.codePeriodsPerBit   = 1;
            settings.dataBitTime       = 1;     
            
            settings.rowH              = 81;    
            settings.colH              = 162;
            settings.symbolsPerFrame   = 81;    
            
        otherwise
            error('initSettings: Unknown messageType "%s". Options: B1C_2, B1C_3, B2a, B2b.', messageType);
    end

    % Compatibility alias used by the supplied getFliterCoef convention.
    settings.IF = settings.intermediateFreq;
    
    %% =================  Pre-computation =================
    % Generate and cache the Galois Field multiplication table for efficiency.
    settings.gfMulTable = getGfTable();
    
end
