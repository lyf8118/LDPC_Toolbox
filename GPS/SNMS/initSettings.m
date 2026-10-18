function settings = initSettings(messageType)
% =========================================================================
% Initializes simulation parameters and system configurations.
% Supports GPS L1C (CNAV-2) binary LDPC for Subframe 2 / Subframe 3.
% =========================================================================

    %% ================= Common Parameters (Global) =================
    settings.simLevel           = 'SYMBOL_LEVEL'; % Direct correlator-output statistics

    % --- Simulation Control ---
    settings.numTrials          = 200;
    settings.cn0Range           = 15:1:20;    
    settings.messageType        = messageType;
    settings.maxIterations      = 15;
    settings.codeFreqBasis      = 1.023e6;   % [Hz]
    settings.codeLength         = 10230;     % [chips]
    settings.dataBitTime        = 10;        % [ms]
    settings.bitsPerSymbol      = 1;
    settings.gfBits             = 1;
    settings.gfSize             = 2;
    %% ================= Signal-Specific Parameters =================
    switch messageType

        % ================= GPS L1C: Subframe 2 (binary LDPC) =================
        case 'L1C_2'
            fprintf('[-] Loading configuration for signal: L1C Subframe 2\n');
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
