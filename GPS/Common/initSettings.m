function settings = initSettings(messageType,simLevel)
% =========================================================================
% Initializes simulation parameters and system configurations.
% Supports GPS L1C (CNAV-2) binary LDPC for Subframe 2 / Subframe 3.
% =========================================================================

    %% ================= Common Parameters (Global) =================
    % SAMPLE_LEVEL uses a real low-IF front end.  The bandwidth is the
    % two-sided RF/IF bandwidth; after down-conversion the LPF cutoff is
    % FeBandwidth/2.
    settings.intermediateFreq   = 2e6;        % Real IF [Hz]
    settings.IF                 = settings.intermediateFreq;
    settings.FeBandwidth        = 3e6;        % Total filter bandwidth [Hz]
    settings.samplingFreq       = 8e6;        % [Hz]
    settings.FeOrder            = 128;        % Even FIR order
    settings.gwnAmp             = 40;         % Noise amplitude scaling
    settings.fileType           = 1;          % Real IF only
    settings.waveformChunkSamples = 1e6;      % Max samples held per streamed chunk

    % --- Simulation Control ---
    settings.numTrials          = 1;
    settings.cn0Range           = 16:1:22;    
    settings.messageType        = messageType;
    settings.cn0Reference       = 'DATA_COMPONENT';
    settings.maxIterations      = 15;
    settings.codeFreqBasis      = 1.023e6;   % [Hz]
    settings.codeLength         = 10230;     % [chips]
    settings.dataBitTime        = 10;        % [ms]
    settings.bitsPerSymbol      = 1;
    settings.gfBits             = 1;
    settings.gfSize             = 2;
    settings.simLevel           = simLevel;
    % SAMPLE_LEVEL waveform selection.  messageType determines the
    % standards-compatible data-channel modulation below; this switch is
    % retained only to allow regression against the former BPSK-equivalent
    % waveform model.
    settings.waveformMode       = 'SIGNAL_SPECIFIC'; % or 'BPSK_EQUIVALENT'
    settings.signalComponent    = 'DATA';
    settings.prn                = 1;         % GPS L1C-D PRN number
    settings.alpha              = 1;         % Normalized MS Scaling coefficient  0.7-0.9
    settings.offset             = 0.2;       % Offset MS coefficient  0.15-0.2
    %% ================= Signal-Specific Parameters =================
    switch messageType

        % ================= GPS L1C: Subframe 2 (binary LDPC) =================
        case 'L1C_2'
            fprintf('[-] Loading configuration for signal: L1C Subframe 2\n');
            settings.signalName        = 'L1C';
            settings.modulationType    = 'BOC11';
            settings.subcarrierFreq    = 1.023e6;
            settings.codePeriod        = 10e-3;
            settings.codePeriodsPerBit = 1;
            % ---- Binary LDPC parameters per IS-GPS-800 ----
            settings.crcLen           = 24;
            settings.payloadBits      = 576;
            settings.ldpcK            = 600;       % payload + CRC
            settings.ldpcN            = 1200;      % coded bits
            settings.ldpcM            = 600;       % parity-check rows

            settings.rowH             = settings.ldpcM;  % M
            settings.colH             = settings.ldpcN;  % N

            settings.symbolsPerFrame  = settings.ldpcK;


        % ================= GPS L1C: Subframe 3 (binary LDPC) =================
        case 'L1C_3'
            fprintf('[-] Loading configuration for signal: L1C Subframe 3\n');
            settings.signalName        = 'L1C';
            settings.modulationType    = 'BOC11';
            settings.subcarrierFreq    = 1.023e6;
            settings.codePeriod        = 10e-3;
            settings.codePeriodsPerBit = 1;

            settings.crcLen           = 24;
            settings.payloadBits      = 250;
            settings.ldpcK            = 274;       % payload + CRC
            settings.ldpcN            = 548;       % coded bits
            settings.ldpcM            = 274;       % parity-check rows

            settings.rowH             = settings.ldpcM;
            settings.colH             = settings.ldpcN;

            settings.symbolsPerFrame  = settings.ldpcK;

        otherwise
            error('initSettings: Unknown messageType "%s".', messageType);
    end
end
