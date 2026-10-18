function [trackResults, channel]= tracking_SIMD_GPU(fid, channel, settings)
% Performs code and carrier tracking for all channels.
%
%[trackResults, channel] = tracking(fid, channel, settings)
%
%   Inputs:
%       fid             - file identifier of the signal record.
%       channel         - PRN, carrier frequencies and code phases of all
%                       satellites to be tracked (prepared by preRum.m from
%                       acquisition results).
%       settings        - receiver settings.
%   Outputs:
%       trackResults    - tracking results (structure array). Contains
%                       in-phase prompt outputs and absolute spreading
%                       code's starting positions, together with other
%                       observation data from the tracking loops. All are
%                       saved every millisecond.

%--------------------------------------------------------------------------
%                         CU Multi-GNSS SDR
% (C) Developed for BDS B2b SDR by Yafeng Li, Nagaraj C. Shivaramaiah
% and Dennis M. Akos.
% Based on the original framework for GPS C/A SDR by Darius Plausinaitis,
% Peter Rinder, Nicolaj Bertelsen and Dennis M. Akos
%--------------------------------------------------------------------------

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

%CVS record:
%$Id: tracking.m,v 1.14.2.31 2006/08/14 11:38:22 dpl Exp $

%% Initialize result structure ====================================
% Channel status
trackResults.status         = '-';      % No tracked signal, or lost lock
% The absolute sample in the record of the C/A code start:
trackResults.absoluteSample = zeros(1, settings.msToProcess);
% Freq of the PRN code:
trackResults.codeFreq       = inf(1, settings.msToProcess);
% Frequency of the tracked carrier wave:
trackResults.carrFreq       = inf(1, settings.msToProcess);
% Outputs from the correlators (In-phase):
trackResults.I_P            = zeros(1, settings.msToProcess);
trackResults.I_E            = zeros(1, settings.msToProcess);
trackResults.I_L            = zeros(1, settings.msToProcess);
% Outputs from the correlators (Quadrature-phase):
trackResults.Q_E            = zeros(1, settings.msToProcess);
trackResults.Q_P            = zeros(1, settings.msToProcess);
trackResults.Q_L            = zeros(1, settings.msToProcess);
% Loop discriminators
trackResults.dllDiscr       = inf(1, settings.msToProcess);
trackResults.dllDiscrFilt   = inf(1, settings.msToProcess);
trackResults.pllDiscr       = inf(1, settings.msToProcess);
trackResults.pllDiscrFilt   = inf(1, settings.msToProcess);
% Remain code and carrier phase
trackResults.remCodePhase   = inf(1, settings.msToProcess);
trackResults.remCarrPhase   = inf(1, settings.msToProcess);
% C/No and PLL lock detector of data channel
trackResults.CNo  = zeros(1,floor(settings.msToProcess/  ...
    settings.CNoInterval));
trackResults.PLD  = zeros(1,floor(settings.msToProcess/ ...
    settings.CNoInterval));
%--- Copy result variables for all channels -------------------------------
% Construct result structure for all channels to be tracked
trackResults = repmat(trackResults, 1, settings.numberOfChannels);

%% Construct variables for tracking loops =========================
% Count of channels to be tracked
channelCnt = nnz([channel.status]== 'T');
% Code tracking loop parameters
oldCodeNco   = zeros(1,channelCnt);
oldCodeError = zeros(1,channelCnt);
% Carrier/Costas loop parameters
oldCarrNco   = zeros(1,channelCnt);
oldCarrError = zeros(1,channelCnt);
% Define initial code frequency basis of NCO
codeFreq      = [channel(1:channelCnt).codeFreq];
% C/No values for all channles
CNo = zeros(1,channelCnt);
% Define residual code phase (in chips)
remCodePhase  = zeros(1,channelCnt);
% Define residual carrier phase
remCarrPhase  = zeros(1,channelCnt);
% Define carrier frequency which is used over whole tracking period
carrFreq      = [channel(1:channelCnt).acquiredFreq];
carrFreqBasis = [channel(1:channelCnt).acquiredFreq];
% The absolute sample in the record of the C/A code start for all channels.
% In addition skip through that data file to start at the appropriate
% sampling points.
absoluteSample = settings.skipNumberOfBytes + ...
    [channel(1:channelCnt).codePhase] - 1;

% Generate the C/A code table for acqired signals
for channelNr = 1:channelCnt
    % Get a vector with the B2bI data code sampled 1x/chip
    B2bICode = generateB2bICode(channel(channelNr).PRN,settings);
    % Then make it possible to do early and late versions
    B2bICodeTable(channelNr,:) = [B2bICode(end) B2bICode B2bICode(1)];  %#ok<AGROW>
end

if settings.trkMode == 1
    % For SIMD MEX formatting
    B2bICodeTable = int32(B2bICodeTable');
elseif settings.trkMode == 2
    % For GPU MEX formatting
    B2bICodeTable = int8(B2bICodeTable');
end
%% Initialize tracking variables ==================================
% Code periods to be processed
codePeriods = settings.msToProcess;     % For BDS one B2bI code is one ms
%--- DLL variables --------------------------------------------------------
% Summation interval
PDIcode = settings.intTime;
% Calculate filter coefficient values
[tau1code, tau2code] = calcLoopCoef(settings.dllNoiseBandwidth, ...
    settings.dllDampingRatio,1.0);
%--- PLL variables --------------------------------------------------------
% Summation interval
PDIcarr = settings.intTime;
% Calculate filter coefficient values
[tau1carr, tau2carr] = calcLoopCoef(settings.pllNoiseBandwidth, ...
    settings.pllDampingRatio, 0.25);

%% Initialize waitbar and variables for data reading ==============
% -------- Initialize waitbar ---------------------------------------------
hwb = waitbar(0,'Tracking...');
%Adjust the size of the waitbar to insert text
CNoPos = get(hwb,'Position');
set(hwb,'Position',[CNoPos(1),CNoPos(2),CNoPos(3),90],'Visible','on');

% -------- Variables for IF signal reading --------------------------------
if (settings.fileType==1)
    dataAdaptCoeff=1;
else
    dataAdaptCoeff=2;
end

% Current SIMD/GPU MEX correlators both expect int16 IF samples.
dataConverter = strcat(settings.dataType,'=>int16');

% Initialize the absolute sample indexe for the end of the current signal
% block read from the IF file:
blockEndIndex = 0;
% Find number of samples per spreading code
samplesPerCode = round(settings.samplingFreq / ...
    (settings.codeFreqBasis / settings.codeLength));
% Number of samples per second
samplesPerSec = samplesPerCode * 1000;

%% ============= Tracking processing for all channels =============
%  1)  GUI update
%  2)  Read next block of data
%  3)  SIMD/GPU Correlator implementation
%  4)  Update tracking-loop variables
%  5)  CNo calculation
% =========================================================================
% Process the number of specified code periods
for loopCnt =  1:codePeriods
    %% GUI update -------------------------------------------------
    % The GUI is updated every 2s. This way Matlab GUI is still
    % responsive enough. At the same time Matlab is not occupied
    % all the time with GUI task.
    if (rem(loopCnt, 2000) == 0)
        Ln = newline;
        trackingStatus=['Tracking ', int2str(channelCnt),' PRNs:',Ln ...
            '1st PRN: ', int2str(channel(1).PRN),Ln ...
            'Completed ',int2str(loopCnt), ...
            ' of ', int2str(codePeriods), ' msec',Ln...
            '1st C/No: ',int2str(CNo(  1)),' (dB-Hz)'];
        try
            waitbar(loopCnt/codePeriods,hwb,trackingStatus);
        catch
            % The progress bar was closed. It is used as a signal
            % to stop, "cancel" processing. Exit.
            disp('Progress bar closed, exiting...');
            return
        end
    end
    
    %% Read next block of data ------------------------------------
    % Code phase step based on code freq. and sampling frequency (fixed)
    codePhaseStep = codeFreq / settings.samplingFreq;
	% Carrier phase step in rad based on carrier freq and sampling frequency
    carrPhaseStep = carrFreq * 2.0 * pi / settings.samplingFreq;
    % Find the size of a code period in whole samples for all channles
    chSampleSize = ceil((settings.codeLength - remCodePhase) ./ codePhaseStep);
    
    % Data reading flag
    dataReadFlag = 0;
    % If the maximum index of the starting point for the next block exceeds
    % the current high boundary of the data segment, then a new block will
    % be read.
    if blockEndIndex <= max(absoluteSample + chSampleSize)
        % Update data reading flag
        dataReadFlag = 1;
        % The starting point is the minimum index for all channels
        blockStartIndex = min(absoluteSample);
        % Seek the starting point of next data block to be processed.
        if strcmp(settings.dataType,'int16')
            fseek(fid, dataAdaptCoeff * blockStartIndex * 2,'bof');
        else
            fseek(fid, dataAdaptCoeff * blockStartIndex,'bof');
        end
        
        % Read 1 second number of samples for the next data block
        [rawSignal, samplesRead] = fread(fid,...
            dataAdaptCoeff * samplesPerSec, dataConverter);
        
        % If did not read in enough samples, then could be out of
        % data - better exit
        if (samplesRead ~= dataAdaptCoeff * samplesPerSec)
            disp('Not able to read the specified number of samples for tracking, exiting!')
            fclose(fid);
            return
        end
        % Update end sample indexes of current block
        blockEndIndex = blockStartIndex + samplesPerSec - 1;
    end
    
    %% SIMD/GPU Correlator implementation -------------------------
    % Start index of each channel block within the 1-sec "rawSignal"
    startIndex = absoluteSample - blockStartIndex + 1;
    % The current MEX correlators wipe the carrier with exp(-j*phase) and
    % return [real; imag]. The original MATLAB tracking loop uses
    % exp(+j*phase), then treats imag as I and real as Q. Negating the phase
    % here and swapping rows below preserves that established convention.
    mexRemCarrPhase = -remCarrPhase;
    mexCarrPhaseStep = -carrPhaseStep;
    
    if settings.trkMode == 1 % Using SIMD of CPU
        % Compile the MEX file with: mex corrSIMDParallelBPSK.cpp
        correValues = corrSIMDParallelBPSK(settings, rawSignal, B2bICodeTable, ...
            mexRemCarrPhase,mexCarrPhaseStep,remCodePhase,codePhaseStep,...
            int32(startIndex),int32(chSampleSize),dataReadFlag);
    elseif settings.trkMode == 2 % Using GPU
        % Compile the MEX file with: mexcuda corrGPUParallelBPSK.cu
        correValues = corrGPUParallelBPSK(settings, rawSignal, B2bICodeTable, ...
            mexRemCarrPhase,mexCarrPhaseStep,remCodePhase,codePhaseStep,...
            int32(startIndex),int32(chSampleSize),dataReadFlag);
    end
    correValues = correValues([2 1 4 3 6 5], :);
    
    %% Update tracking-loop variables for all channels ------------
    for channelNr = 1:channelCnt
        % Now get early, late, and prompt values for each branch of
        % correlator
        I_E = correValues(1,channelNr); Q_E = correValues(2,channelNr);
        I_P = correValues(3,channelNr); Q_P = correValues(4,channelNr);
        I_L = correValues(5,channelNr); Q_L = correValues(6,channelNr);
        
        % Save remCodePhase for current correlation
        trackResults(channelNr).remCodePhase(loopCnt) = remCodePhase(channelNr);
        % Save remCarrPhase for current correlation
        trackResults(channelNr).remCarrPhase(loopCnt) = remCarrPhase(channelNr);
        % Update the remCodePhase and remCarrPhase
        remCodePhase(channelNr) = chSampleSize(channelNr) * codePhaseStep(channelNr)...
            + remCodePhase(channelNr) - settings.codeLength;
        remCarrPhase(channelNr) = rem(carrPhaseStep(channelNr) * ...
            chSampleSize(channelNr) + remCarrPhase(channelNr), 2 * pi);
        
        % Find PLL error and update carrier NCO ---------------------------
        % Implement carrier loop discriminator (phase detector)
        carrError = atan(Q_P / I_P) / (2.0 * pi);
        % Implement carrier loop filter and generate NCO command
        carrNco = oldCarrNco(channelNr) + (tau2carr/tau1carr) * ...
            (carrError - oldCarrError(channelNr)) + carrError * (PDIcarr/tau1carr);
        oldCarrNco(channelNr)   = carrNco;
        oldCarrError(channelNr) = carrError;
        % Save carrier frequency for current correlation
        trackResults(channelNr).carrFreq(loopCnt) = carrFreq(channelNr);
        % Modify carrier freq based on NCO command
        carrFreq(channelNr) = carrFreqBasis(channelNr) + carrNco;
        
        % Find DLL error and update code NCO ------------------------------
        codeError = (sqrt(I_E^2 + Q_E^2) - sqrt(I_L^2 + Q_L^2)) / ...
            (sqrt(I_E^2 + Q_E^2) + sqrt(I_L^2 + Q_L^2));
        % Implement code loop filter and generate NCO command
        codeNco = oldCodeNco(channelNr) + (tau2code/tau1code) * ...
            (codeError - oldCodeError(channelNr)) + codeError * (PDIcode/tau1code);
        oldCodeNco(channelNr)   = codeNco;
        oldCodeError(channelNr) = codeError;
        % Save code frequency for current correlation
        trackResults(channelNr).codeFreq(loopCnt) = codeFreq(channelNr);
        % Modify code freq based on NCO command
        codeFreq(channelNr) = channel(channelNr).codeFreq - codeNco;
        
        % Record sample number based on the settings.dataType
        trackResults(channelNr).absoluteSample(loopCnt) = absoluteSample(channelNr);
        % Update sample index for next "loopCnt"
        absoluteSample(channelNr) = absoluteSample(channelNr) + chSampleSize(channelNr);
        
        % Record various measures to show in postprocessing ---------------
        trackResults(channelNr).dllDiscr(loopCnt)     = codeError;
        trackResults(channelNr).dllDiscrFilt(loopCnt) = codeNco;
        trackResults(channelNr).pllDiscr(loopCnt)     = carrError;
        trackResults(channelNr).pllDiscrFilt(loopCnt) = carrNco;
        trackResults(channelNr).I_E(loopCnt) = I_E;
        trackResults(channelNr).I_P(loopCnt) = I_P;
        trackResults(channelNr).I_L(loopCnt) = I_L;
        trackResults(channelNr).Q_E(loopCnt) = Q_E;
        trackResults(channelNr).Q_P(loopCnt) = Q_P;
        trackResults(channelNr).Q_L(loopCnt) = Q_L;
        
        % Save additional information before tracking is over
        if loopCnt == codePeriods
            % Each channel's tracked PRN
            trackResults(channelNr).PRN     = channel(channelNr).PRN;
            % If we got so far, this means that the tracking was successful
            % Now we only copy status, but it can be update by a lock detector
            % if implemented
            trackResults(channelNr).status  = channel(channelNr).status;
        end
        
        %% CNo calculation ----------------------------------------
        if (rem(loopCnt,settings.CNoInterval)==0)
            % Computation of CNo and PLL detector output
            [CNoValue, PllDetector]= ...
                Calc_CNo_PLD(trackResults(channelNr),settings,loopCnt);
            % Save C/No 
            CNoCnt = loopCnt/settings.CNoInterval;
            trackResults(channelNr).CNo(CNoCnt) = CNoValue;
            % Save PLL lock detector output for data channel
            trackResults(channelNr).PLD(CNoCnt) = PllDetector;
            CNo(channelNr) = CNoValue;
        end
    end % for channelNr
end % for loopCnt
% Close the waitbar
close(hwb)
clear mex;  %#ok<CLMEX>
