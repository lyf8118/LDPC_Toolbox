function settings = initSettings()
%Functions initializes and saves settings. Settings can be edited inside of
%the function, updated from the command line or updated using a dedicated
%GUI - "setSettings".  
%
%All settings are described inside function code.
%
%settings = initSettings()
%
%   Inputs: none
%
%   Outputs:
%       settings     - Receiver settings (a structure). 
%
%--------------------------------------------------------------------------
%                         CU Multi-GNSS SDR
% (C) Developed for BDS B2b SDR by Yafeng Li, Nagaraj C. Shivaramaiah 
% and Dennis M. Akos. 
% Based on the original framework for GPS C/A SDR by Darius Plausinaitis,
% Peter Rinder, Nicolaj Bertelsen and Dennis M. Akos
%---------------------------------------------------------------------------
%This program is free software; you can redistribute it and/or
%modify it under the terms of the GNU General Public License
%as published by the Free Software Foundation; either version 2
%of the License, or (at your option) any later version.
%
%This program is distributed in the hope that it will be useful,
%but WITHOUT ANY WARRANTY; without even the implied warranty of
%MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%GNU General Public License for more details.
%
%You should have received a copy of the GNU General Public License
%along with this program; if not, write to the Free Software
%Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301,
%USA.
%--------------------------------------------------------------------------

% CVS record:
% $Id: initSettings.m,v 1.9.2.31 2006/08/18 11:41:57 dpl Exp $

%% Processing settings ==============================================
% Number of milliseconds to be processed used 48000 + any transients (see
% below - in Nav parameters) to ensure nav subframes are provided
settings.msToProcess        = 49000;        %[ms]
% Number of channels to be used for signal processing
settings.numberOfChannels   = 15;
% Move the starting point of processing. Can be used to start the signal
% processing at any point in the data record (e.g. for long records). fseek
% function is used to move the file read point, therefore advance is based
% on sampling points. 
settings.skipNumberOfBytes     = 0;

%% Raw signal file name and other parameter =========================
% This is a "default" name of the data file (signal record) to be used in
% the post-processing mode
settings.fileName           = "D:\xiangze\BDS_B2I_B2b.bin";
% Data type used to store one sample
settings.dataType           = 'int16';
% File Types
%1 - 8 bit real samples S0,S1,S2,...
%2 - 8 bit I/Q samples I0,Q0,I1,Q1,I2,Q2,...                      
settings.fileType           = 2;
% Intermediate, sampling 
settings.IF                 = 0.e6;         % [Hz]
settings.samplingFreq       = 30e6;        % [Hz]
%% Code parameter setting
% Define number of chips in a code period and code frequencies of B2b
settings.codeLength           = 10230;         % [chip] 
settings.codeFreqBasis        = 10.23e6;       % [Hz]

%% Acquisition settings =============================================
% Enable use of GPU acceleration for acquisition
settings.gpuACQflag         = 1;             % 0 - Off; 1 - On
% Skips acquisition in the script postProcessing.m if set to 1
settings.skipAcquisition    = 0;
% List of satellites to look for. B2b PRN range is 6:58.
settings.acqSatelliteList   = 6:58;         % [PRN numbers]
% Band around IF to search for satellite signal. Depends on max Doppler.
% It is single sideband, so the whole search band is tiwce of it.
settings.acqSearchBand      = 5000;            % [Hz]
% Non-coherent integration times after 10ms coherent integration
settings.acqNonCohTime      = 10;               
% Threshold for the signal presence decision rule
settings.acqThreshold       = 3;
% Frequency search step for coarse acquisition
settings.acqSearchStep      = 500;             % [Hz]

%% Tracking loops settings ==========================================
% Enable/dissable use of SIMD MEX to accelerate tracking
settings.trkMode                 = 1;   % 0 - Matlab correlator; 
                                        % 1 - SIMD correlator;
                                        % 2 - GPU correlator;
settings.correlatorType          = settings.trkMode;
% if setting.trkMode=1
settings.rShiftBits              = 4;   % Right-shift IF samples before SIMD processing
% Code tracking loop parameters
settings.dllDampingRatio         = 0.7;
settings.dllNoiseBandwidth       = 1.5;       %[Hz]
settings.dllCorrelatorSpacing    = 0.5;        % [chips]
% Carrier tracking loop parameters
settings.pllDampingRatio         = 0.7;
settings.pllNoiseBandwidth       = 20;         %[Hz]
% Integration time for DLL and PLL 
settings.intTime                 = 0.001;      % [s]

%% Navigation solution settings =====================================
% Period for calculating pseudoranges and position
settings.navSolPeriod       = 500;            % [ms]
% Elevation mask to exclude signals from satellites at low elevation
settings.elevationMask      = 5;              %[degrees 0 - 90]
% Enable/dissable use of tropospheric correction
settings.useTropCorr        = 1;              % 0 - Off; 1 - On
% True position of the antenna in UTM system (if known). Otherwise enter
% all NaN's and mean position will be used as a reference .
settings.truePosition.E     = nan;
settings.truePosition.N     = nan;
settings.truePosition.U     = nan;

%% Plot settings ====================================================
% Enable/disable plotting of the tracking results for each channel
settings.plotTracking       = 1;            % 0 - Off; 1 - On

%% Constants ========================================================
% The speed of light 
settings.c                  = 299792458;    %[m/s]
% Initial sign. travel time. It is 68.802 ms for BDS MEO and 120 ms for
% GEO/IGSO which is 35,786 km from MSL. Here we take 94 ms as an average value. 
settings.startOffset        = 94;           %[ms] 

%% CNo Settings====================================================
% Number of correlation values used to compute each C/No point
settings.CNoInterval = 200;

%% BDS-3 B2b carrier frequency ====================================
settings.carrFreqBasis    = 1207.14e6;      % [Hz]
%% BDS-3 B2b LDPC
settings.messageType       = 'B2b';
settings.decoderType       = 'SNEMS';       % EMS, FFT-QSPA, NEMS, SNEMS
settings.maxIterations     = 15;
settings.nmEms             = 4;           % EMS truncation size
settings.alpha             = 1.0;         % 1.0: EMS; <1: normalized EMS
settings.offset            = 0;           % >0: offset EMS
settings.gfBits            = 6;
settings.gfSize            = 64;
settings.bitsPerSymbol     = 6;
settings.rowH              = 81;
settings.colH              = 162;
settings.symbolsPerFrame   = 81;
