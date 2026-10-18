An Open-Source MATLAB GNSS LDPC Decoding and Analysis Toolbox
===============================================================================

[中文说明](readme_chinese.md)


Overview
-------------------------------------------------------------------------------
GNSS-LDPC-Toolbox is an open-source MATLAB toolbox for the simulation, implementation, and performance analysis of low-density parity-check (LDPC) decoding for GNSS navigation messages. It provides binary LDPC processing for GPS L1C CNAV-2 and non-binary GF(64) LDPC processing for BDS-3 B1C, B2a, and B2b. Conventional decoders and model-driven neural variants are organized in separate algorithm folders so that they can be evaluated under a common Monte Carlo framework. The toolbox supports both symbol-level simulation and sample-level real-IF
waveform simulation. The symbol-level path provides a fast statistical baseline for decoder studies. The sample-level path includes signal-specific spreading and modulation, a real intermediate-frequency carrier, AWGN, complex down-conversion, front-end low-pass filtering, correlation, and noise estimation. The repository also contains experimental GPS L1C and BDS-3 B2b software-receiver chains for recorded signals, together with MATLAB, SIMD MEX, and CUDA MEX
correlator backends.


Authors
-------------------------------------------------------------------------------
* Yafeng Li
    * E-Mail: <lyf8118@126.com>
    * Wechat: lyf8118521
    * QQ Group for Technical Discussions on GNSS Software Receivers: 147304049


* Anyi Lv
    * E-Mail: <lvanyi521@gmail.com >


Features
-------------------------------------------------------------------------------
* GPS L1C binary LDPC simulation
    * CNAV-2 subframe 2 (L1C_2) and subframe 3 (L1C_3)
    * Belief propagation (BP)
    * Min-Sum (MS), Normalized MS, and Offset MS
    * NeuralMS, NMS training, and shared-weight SNMS
* BDS-3 non-binary LDPC simulation over GF(64)
    * B-CNAV1 subframes B1C_2 and B1C_3
    * B-CNAV2 B2a and B-CNAV3 B2b
    * QSPA and FFT-QSPA
    * EMS, Normalized EMS, and Offset EMS
    * Edge-weighted NEMS and shared-weight SNEMS
* Two simulation-fidelity levels
    * SYMBOL_LEVEL generates statistically equivalent correlator outputs for
      fast decoder validation, training, and parameter studies.
    * SAMPLE_LEVEL generates a real-IF waveform and executes down-conversion,
      front-end filtering, matched correlation, and noise estimation.
* Unified performance evaluation
    * Bit error rate (BER)
    * Frame error rate (FER)
    * Average decoder iteration count
    * Per-frame and per-C/N0 execution-time measurements
    * Independent Monte Carlo trials with optional parfor execution
* Model-driven training
    * Manually implemented loss, gradient, and Adam updates in MATLAB
    * Signal-specific pretrained NEMS/SNEMS and NeuralMS weights
* Recorded-signal receiver experiments
    * GPS L1C acquisition, tracking, CNAV-2/LDPC decoding, and PVT processing
    * BDS-3 B2b acquisition, tracking, B-CNAV3/LDPC decoding, and PVT processing
    * MATLAB, CPU SIMD MEX, and CUDA MEX correlator implementations


Directory and Files
-------------------------------------------------------------------------------
Root folders and documents
    ./GPS                     GPS L1C binary LDPC simulation and training.
    ./BDS                     BDS-3 GF(64) LDPC simulation and training.
    ./Live_Signal_Demo        Recorded-signal GPS L1C and BDS-3 B2b receivers.
    ./output                  Generated results and supporting artifacts.
    ./User_Manual.docx        Detailed toolbox user manual.
    ./README.md               English project description.
    ./readme_chinese.md       Chinese project description.
    ./license.txt             GNU GPL version 3 or later.

GPS LDPC folders
    ./GPS/Common              Shared encoders, signal models, settings, metrics,
                              and plotting functions.
    ./GPS/BP                  Binary sum-product/BP decoder.
    ./GPS/MS                  MS, Normalized MS, and Offset MS decoder.
    ./GPS/NeuralMS            Pretrained NeuralMS inference.
    ./GPS/NMSTrain            NMS parameter training.
    ./GPS/SNMS                Shared-weight SNMS training and inference.
    ./GPS/compare_gps.m       Unified GPS multi-algorithm comparison.

BDS LDPC folders
    ./BDS/Common              Shared GF(64) encoders, parity-check matrices,
                              signal models, settings, metrics, and plotting.
    ./BDS/QSPA                Non-binary QSPA decoder.
    ./BDS/FFT-QSPA            FFT-accelerated QSPA decoder.
    ./BDS/EMS                 EMS, Normalized EMS, and Offset EMS decoder.
    ./BDS/NEMS                Pretrained edge-weighted NEMS inference.
    ./BDS/SNEMS               Pretrained shared-weight SNEMS inference.
    ./BDS/NEMSTRAIN           NEMS parameter training.
    ./BDS/SNEMSTRAIN          SNEMS parameter training.
    ./BDS/compareldpc.m       Unified BDS multi-algorithm comparison.

Recorded-signal folders
    ./Live_Signal_Demo/GPS_L1C
                              GPS L1C software-receiver chain; entry: init.m.
    ./Live_Signal_Demo/BDS-3_B2b
                              BDS-3 B2b software-receiver chain; entry: init.m.
    ./Live_Signal_Demo/Mex_files
                              SIMD/CUDA source and Windows MEX binaries.


Software Dependencies
-------------------------------------------------------------------------------
* MATLAB is required. The current toolbox has been smoke-tested with MATLAB
  R2023b on Windows.
* Communications Toolbox is required for Galois-field operations such as gf()
  and for signal-dependent channel-coding functions.
* Parallel Computing Toolbox is required by parfor-based demonstrations and
  MATLAB GPU-array processing.
* Signal Processing Toolbox is required by the sample-level FIR front end and
  selected recorded-signal inspection and spectrum-analysis functions.
* A supported C/C++ compiler is required to rebuild the SIMD MEX correlators.
* A compatible NVIDIA GPU, driver, CUDA toolkit, and mexcuda environment are
  required to rebuild or execute the CUDA MEX correlators.
* Bundled .mexw64 binaries are platform- and MATLAB-ABI-dependent. Recompile
  them when using an incompatible MATLAB release or operating system.


How to use
-------------------------------------------------------------------------------
* Step 1: Start MATLAB and change the current folder to the GLDA repository root.
* Step 2: Record the root path:

      toolboxRoot = pwd;

* Step 3: Enter exactly one algorithm folder. Do not recursively add the entire
          repository because different algorithms intentionally contain
          functions with identical names.
* Step 4: Select messageType and simLevel in the target demonstration script.
* Step 5: Reduce numTrials and cn0Range for the first functional check, then
          restore the experiment settings for formal Monte Carlo evaluation.
* Step 6: Run the selected entry script and inspect BER, FER, average iteration
          count, timing output, and generated plots.

GPS L1C BP example

    cd(fullfile(toolboxRoot, 'GPS', 'BP'));
    ldpcBpGPSDemo

BDS-3 B2b QSPA example

    cd(fullfile(toolboxRoot, 'BDS', 'QSPA'));
    ldpcQspaBDSDemo

BDS NEMS example

    cd(fullfile(toolboxRoot, 'BDS', 'NEMS'));
    ldpcNemsBDSDemo

Unified GPS comparison

    cd(fullfile(toolboxRoot, 'GPS'));
    compare_gps

Unified BDS comparison

    cd(fullfile(toolboxRoot, 'BDS'));
    compareldpc

When switching algorithms, clear cached functions and verify the resolved paths:

    clear functions
    rehash
    which initSettings -all
    which ldpcDecoderGPS -all
    which ldpcDecoderBDS -all


Simulation Configuration
-------------------------------------------------------------------------------
The shared settings factories are:

    ./GPS/Common/initSettings.m
    ./BDS/Common/initSettings.m

Current shared defaults (values in the source, before user changes)

| Setting | GPS | BDS |
| --- | --- | --- |
| `numTrials` per C/N0 point | `1` | `1000` |
| `cn0Range` (dB-Hz) | `16:1:22` | `16:1:22` for all four message types |
| `maxIterations` | `15` | `15` |
| `alpha` | `1` | `0.8` |
| `offset` | `0.2` | `0` |
| `nmEms` | Not used | `4` |

With these settings, the GPS `MS` folder runs Offset MS (OMS), and the BDS
`EMS` folder runs Normalized EMS. The alpha/offset settings select those
conventional variants; they do not change the BP, QSPA, or neural decoder
selection. Training folders have independent settings.

The standalone GPS BP/MS/NeuralMS demonstrations default to `L1C_2` and
`SYMBOL_LEVEL`; `GPS/compare_gps.m` defaults to `L1C_2` and `SAMPLE_LEVEL`.
The BDS EMS demonstration defaults to `B1C_2`; the QSPA/FFT-QSPA/NEMS/SNEMS
demonstrations and `BDS/compareldpc.m` default to `B2b`. All these BDS entries
default to `SYMBOL_LEVEL`. Select another message or level in the entry script.

For a B2b performance study, `26:1:33` dB-Hz is a suggested C/N0 sweep to set
explicitly; it is not the current code default. Likewise, increase the GPS
`numTrials` beyond its one-frame functional-check default for Monte Carlo
evaluation. Example and suggested settings do not overwrite the defaults above.

Supported simulation levels
    SYMBOL_LEVEL              Statistical correlator-output model with known
                              normalized noise variance. Recommended for fast
                              decoder comparison and neural-weight training.
    SAMPLE_LEVEL              Real-IF waveform generation and receiver
                              processing. Recommended for studying sampling,
                              filtering, correlation, and noise-estimation loss.

Default sample-level front-end configurations
    GPS L1C                   IF 2 MHz, total filter bandwidth 3 MHz,
                              sampling frequency 8 MHz.
    BDS B1C                   IF 4 MHz, total filter bandwidth 5 MHz,
                              sampling frequency 16 MHz.
    BDS B2a                   IF 15 MHz, total filter bandwidth 25 MHz,
                              sampling frequency 60 MHz.
    BDS B2b                   IF 15 MHz, total filter bandwidth 25 MHz,
                              sampling frequency 60 MHz.

Important decoder settings
    settings.maxIterations    Maximum number of decoding iterations.
    settings.nmEms            Number of retained EMS candidates.
    settings.alpha            Normalization coefficient for MS/EMS variants.
    settings.offset           Offset coefficient for MS/EMS variants.
    settings.numTrials        Number of independent Monte Carlo frames per
                              C/N0 point.
    settings.cn0Range         Simulated carrier-to-noise-density range.

The implementations support parity-check-based early termination. Average
iteration count therefore represents the actual number of iterations executed,
not always settings.maxIterations. Timing comparisons should state whether pool
startup, waveform generation, and plotting are included.


Model-Driven Training
-------------------------------------------------------------------------------
The model-driven decoders unfold MS or EMS iterations and learn scaling or damping parameters with explicit MATLAB gradient calculations and Adam updates. Training and inference are normally selected with doTraining in the relevant entry script:

    doTraining = true;        % train and save new weights
    doTraining = false;       % load pretrained weights

Current entry defaults (all four training/test chains use `SYMBOL_LEVEL`):

| Entry script | `messageType` | `doTraining` |
| --- | --- | --- |
| `GPS/NMSTrain/neuralMsGPSDemo.m` | `L1C_2` | `false` |
| `GPS/SNMS/neuralMsGPSDemo.m` | `L1C_2` | `true` |
| `BDS/NEMSTRAIN/neuralEmsDemo.m` | `B2b` | `false` |
| `BDS/SNEMSTRAIN/ShareNeuralEmsDemo.m` | `B2a` | `false` |

Before training, verify the message type, training C/N0 range, epoch count, maximum iteration count, random seed, and output weight filename. Each training folder contains its own settings and decoder functions; keep unrelated algorithm folders off the MATLAB path.


Recorded-Signal Processing
-------------------------------------------------------------------------------
Raw IF/IQ recordings are not included in this repository. Before running a recorded-signal receiver, configure the input filename, data type, real/IQ file format, intermediate frequency, sampling frequency, processing duration, and correlator backend in the receiver's initSettings.m.

GPS L1C

    cd(fullfile(toolboxRoot, 'Live_Signal_Demo', 'GPS_L1C'));
    init

BDS-3 B2b

    cd(fullfile(toolboxRoot, 'Live_Signal_Demo', 'BDS-3_B2b'));
    init

Current receiver defaults are defined in each receiver's `initSettings.m`:

| Setting | GPS L1C | BDS-3 B2b |
| --- | --- | --- |
| `fileName` (replace with your recording) | `D:\xiangze\GPS L1C.iq` | `D:\xiangze\BDS_B2I_B2b.bin` |
| `dataType` / `fileType` | `int8` / `2` (interleaved I/Q) | `int16` / `2` (interleaved I/Q) |
| `IF` / `samplingFreq` | `0` / `25e6` Hz | `0` / `30e6` Hz |
| `msToProcess` / `numberOfChannels` | `40000` ms / `15` | `49000` ms / `15` |
| Acquisition | `gpuACQflag=1`, PRNs `1:32` | `gpuACQflag=1`, PRNs `6:58` |
| Tracking | `trkMode=1` (channel-parallel), `correlatorType=2` (GPU) | `trkMode=1`, `correlatorType=1` (SIMD), `rShiftBits=4` |
| `intTime` | `0.01` s | `0.001` s |
| LDPC decoder | `ldpcDecoderType='MS'` (OMS) | `decoderType='SNEMS'` |
| LDPC iterations / EMS candidates | `ldpcMaxIterations=15` | `maxIterations=15`, `nmEms=4` |
| Conventional MS/EMS parameters | `ldpcMsAlpha=1`, `ldpcMsOffset=0.2` | `alpha=1.0`, `offset=0` (used when selecting EMS) |

The two receivers use different meanings for `trkMode`: GPS selects serial or
parallel channel processing, while B2b selects the MATLAB/SIMD/GPU backend.
These recorded-signal settings are separate from the simulation front ends.

The BDS-3 B2b recorded-signal chain currently relies on its implemented GPU acquisition path unless valid acquisition results are supplied. Match all IF settings to the recording metadata before interpreting receiver results.


Implementation Details
-------------------------------------------------------------------------------
Each algorithm folder contains a decoder implementation with a common external interface. The comparison scripts dynamically add one algorithm folder at a time, execute the same encoding and channel chain, archive the metrics, and remove that folder before loading the next decoder. This directory isolation is required because ldpcDecoderGPS.m, ldpcDecoderBDS.m, initLlr.m, and several helper names are intentionally reused.

GPS L1C uses binary parity-check matrices and bit-domain soft information. BDS B1C/B2a/B2b use GF(64) parity-check matrices and non-binary symbol metrics. The shared simulation settings use `cn0Reference='DATA_COMPONENT'`: C/N0 is referenced to the simulated data component (the I component for B2b). The current model generates that component directly and has no separate configurable data/pilot power-fraction parameter.

The sample-level implementation processes long waveforms in chunks to avoid storing a complete frame waveform in memory. The real-IF signal is mixed to complex baseband, passed through the configured low-pass filter, and correlated with the signal-specific sampled replica. Finite sampling, filtering, and noise estimation can therefore introduce a small implementation loss relative to the symbol-level statistical baseline.

Portions of the recorded-signal receivers follow the SoftGNSS architecture and retain their original author and license notices. Third-party code and materials remain subject to their original copyright and license terms.


Reproducibility
-------------------------------------------------------------------------------
For reproducible BER/FER and timing results, record the following information:
* MATLAB and toolbox versions.
* Signal type, simulation level, decoder, and complete settings structure.
* Random seed, number of Monte Carlo frames, and parallel-worker count.
* Maximum iterations, EMS candidate count, normalization/offset parameters,
  early-termination policy, and neural-weight training range.
* CPU, GPU, memory, operating system, and MEX backend.
* Whether timing includes encoding, channel simulation, pool startup, plotting,
  or only LDPC decoding.

A measured BER or FER of zero means that no error was observed in the finite number of simulated frames; it is not proof that the true error probability is zero.


License
-------------------------------------------------------------------------------
GLDA is distributed under the GNU General Public License, version 3 or later.
See ./license.txt for the complete terms. Third-party source files and materials
retain their original notices and applicable licenses.


