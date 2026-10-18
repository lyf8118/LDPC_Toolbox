An Open-Source MATLAB GNSS LDPC Decoding and Analysis Toolbox
===============================================================================

[English README](README.md)


Overview
-------------------------------------------------------------------------------
GLDA 是一个面向 GNSS 导航电文 LDPC 编译码、实现与性能分析的 MATLAB 开源工具箱。工具箱提供 GPS L1C CNAV-2 二进制 LDPC 处理，以及北斗三号 B1C、B2a和 B2b 的 GF(64) 多进制 LDPC 处理。传统译码算法与模型驱动神经译码算法分别放置在独立目录中，可通过统一的蒙特卡洛仿真框架进行公平比较。

工具箱同时支持符号级仿真和采样级实中频波形仿真。符号级路径用于快速生成统计等效软信息，适合译码算法验证、训练和参数扫描；采样级路径包含信号特定扩频与调制、实中频载波、AWGN、复数下变频、前端低通滤波、相关积分和噪声估计。仓库还包含面向录制信号的 GPS L1C 与 BDS-3 B2b 实验性软件接收机，以及MATLAB、SIMD MEX 和 CUDA MEX 相关器后端。


Authors
-------------------------------------------------------------------------------
* Yafeng Li
    * E-Mail: <lyf8118@126.com>
    * Wechat: lyf8118521
    * GNSS 软件接收机技术讨论 QQ 群：147304049


* Anyi Lv
    * E-Mail: <lvanyi521@gmail.com>


Features
-------------------------------------------------------------------------------
* GPS L1C 二进制 LDPC 仿真
    * CNAV-2 子帧 2（L1C_2）和子帧 3（L1C_3）
    * 置信传播 BP
    * Min-Sum、Normalized MS 和 Offset MS
    * NeuralMS、NMS 训练和共享权重 SNMS
* 北斗三号 GF(64) 多进制 LDPC 仿真
    * B-CNAV1 的 B1C_2 与 B1C_3
    * B-CNAV2 B2a 和 B-CNAV3 B2b
    * QSPA 与 FFT-QSPA
    * EMS、Normalized EMS 和 Offset EMS
    * 边权重 NEMS 与共享权重 SNEMS
* 两种仿真保真度
    * SYMBOL_LEVEL 直接生成统计等效相关器输出，用于快速译码验证、训练和
      参数研究。
    * SAMPLE_LEVEL 生成实中频波形，并执行下变频、前端滤波、匹配相关和
      噪声估计。
* 统一性能评估
    * 比特错误率 BER
    * 帧错误率 FER
    * 平均实际译码迭代次数
    * 单帧或单个 C/N0 点的运行时间
    * 可通过 parfor 并行执行相互独立的蒙特卡洛试验
* 模型驱动训练
    * 在 MATLAB 中显式实现损失、梯度和 Adam 参数更新
    * 信号对应的 NEMS、SNEMS 和 NeuralMS 预训练权重
* 录制信号实验
    * GPS L1C 捕获、跟踪、CNAV-2/LDPC 译码与 PVT
    * BDS-3 B2b 捕获、跟踪、B-CNAV3/LDPC 译码与 PVT
    * MATLAB、CPU SIMD MEX 和 CUDA MEX 相关器


Directory and Files
-------------------------------------------------------------------------------
根目录与文档
    ./GPS                     GPS L1C 二进制 LDPC 仿真与训练。
    ./BDS                     北斗三号 GF(64) LDPC 仿真与训练。
    ./Live_Signal_Demo        GPS L1C 和 BDS-3 B2b 录制信号接收机。
    ./output                  生成的结果和辅助文件。
    ./User_Manual.docx        工具箱详细用户手册。
    ./README.md               英文项目说明。
    ./readme_chinese.md       中文项目说明。
    ./license.txt             GNU GPL 第 3 版或更高版本许可证。

GPS LDPC 目录
    ./GPS/Common              公共编码、信号模型、配置、指标与绘图函数。
    ./GPS/BP                  二进制和积/BP 译码器。
    ./GPS/MS                  MS、Normalized MS 和 Offset MS 译码器。
    ./GPS/NeuralMS            预训练 NeuralMS 推理。
    ./GPS/NMSTrain            NMS 参数训练。
    ./GPS/SNMS                共享权重 SNMS 训练与推理。
    ./GPS/compare_gps.m       GPS 多算法统一比较。

BDS LDPC 目录
    ./BDS/Common              公共 GF(64) 编码、H 矩阵、信号模型、配置、指标
                              与绘图函数。
    ./BDS/QSPA                多进制 QSPA 译码器。
    ./BDS/FFT-QSPA            FFT 加速 QSPA 译码器。
    ./BDS/EMS                 EMS、Normalized EMS 和 Offset EMS 译码器。
    ./BDS/NEMS                预训练边权重 NEMS 推理。
    ./BDS/SNEMS               预训练共享权重 SNEMS 推理。
    ./BDS/NEMSTRAIN           NEMS 参数训练。
    ./BDS/SNEMSTRAIN          SNEMS 参数训练。
    ./BDS/compareldpc.m       BDS 多算法统一比较。

录制信号目录
    ./Live_Signal_Demo/GPS_L1C
                              GPS L1C 软件接收机处理链；入口为 init.m。
    ./Live_Signal_Demo/BDS-3_B2b
                              BDS-3 B2b 软件接收机处理链；入口为 init.m。
    ./Live_Signal_Demo/Mex_files
                              SIMD/CUDA 源码与 Windows MEX 二进制文件。


Software Dependencies
-------------------------------------------------------------------------------
* 需要 MATLAB。当前工具箱已在 Windows MATLAB R2023b 中完成最小运行验证。
* Communications Toolbox 用于 gf() 等有限域运算以及部分信道编码函数。
* Parallel Computing Toolbox 用于基于 parfor 的演示和 MATLAB GPU-array 处理。
* Signal Processing Toolbox 用于采样级 FIR 前端，以及部分录制信号检查与频谱分析函数。
* 重新编译 SIMD MEX 需要 MATLAB 支持的 C/C++ 编译器。
* 重新编译或运行 CUDA MEX 需要兼容的 NVIDIA GPU、驱动、CUDA 工具链和
  mexcuda 环境。
* 仓库中的 .mexw64 文件依赖 Windows 平台和 MATLAB ABI。使用不兼容的
  MATLAB 版本或操作系统时需要重新编译。


How to use
-------------------------------------------------------------------------------
* Step 1：启动 MATLAB，将当前文件夹切换到 GLDA 仓库根目录。
* Step 2：记录根路径：

      toolboxRoot = pwd;

* Step 3：只进入一个目标算法目录。不同算法有意保留同名函数，不要对整个
          仓库执行递归 addpath。
* Step 4：在目标演示脚本中选择 messageType 和 simLevel。
* Step 5：首次功能检查时减小 numTrials 并缩短 cn0Range；正式仿真时再恢复
          完整实验参数。
* Step 6：运行入口脚本，检查 BER、FER、平均迭代次数、运行时间和结果图。

GPS L1C BP 示例

    cd(fullfile(toolboxRoot, 'GPS', 'BP'));
    ldpcBpGPSDemo

BDS-3 B2b QSPA 示例

    cd(fullfile(toolboxRoot, 'BDS', 'QSPA'));
    ldpcQspaBDSDemo

BDS NEMS 示例

    cd(fullfile(toolboxRoot, 'BDS', 'NEMS'));
    ldpcNemsBDSDemo

GPS 多算法统一比较

    cd(fullfile(toolboxRoot, 'GPS'));
    compare_gps

BDS 多算法统一比较

    cd(fullfile(toolboxRoot, 'BDS'));
    compareldpc

切换算法后，建议清除函数缓存并确认 MATLAB 实际解析的文件路径：

    clear functions
    rehash
    which initSettings -all
    which ldpcDecoderGPS -all
    which ldpcDecoderBDS -all


Simulation Configuration
-------------------------------------------------------------------------------
公共配置入口为：

    ./GPS/Common/initSettings.m
    ./BDS/Common/initSettings.m

当前公共默认值（源码中的值，尚未由用户修改）

| 配置项 | GPS | BDS |
| --- | --- | --- |
| 每个 C/N0 点的 `numTrials` | `1` | `1000` |
| `cn0Range`（dB-Hz） | `16:1:22` | 四种电文均为 `16:1:22` |
| `maxIterations` | `15` | `15` |
| `alpha` | `1` | `0.8` |
| `offset` | `0.2` | `0` |
| `nmEms` | 不使用 | `4` |

按上述默认值，GPS 的 `MS` 目录实际运行 Offset MS（OMS），BDS 的 `EMS`
目录实际运行 Normalized EMS。alpha/offset 用于选择这些传统算法变体，不会
改变 BP、QSPA 或神经译码器的选择。训练目录使用各自独立的配置。

GPS 的 BP/MS/NeuralMS 独立演示默认选择 `L1C_2` 与 `SYMBOL_LEVEL`；
`GPS/compare_gps.m` 默认选择 `L1C_2` 与 `SAMPLE_LEVEL`。BDS 的 EMS 演示
默认选择 `B1C_2`，QSPA/FFT-QSPA/NEMS/SNEMS 演示及 `BDS/compareldpc.m`
默认选择 `B2b`；这些 BDS 入口均默认使用 `SYMBOL_LEVEL`。其他信号或层级
需在入口脚本中选择。

B2b 性能研究可显式将 C/N0 扫描范围设为建议值 `26:1:33` dB-Hz，该范围
不是当前代码默认值。GPS 的默认 `numTrials=1` 用于单帧功能检查，正式蒙特卡洛
评估应增加帧数。示例或建议值均不代表源码已采用这些设置。

支持的仿真层级
    SYMBOL_LEVEL              采用已知归一化噪声方差的统计相关器输出模型，适合
                              快速算法比较和神经权重训练。
    SAMPLE_LEVEL              生成实中频波形并执行接收机处理，适合研究采样、
                              滤波、相关与噪声估计产生的实现损耗。

默认采样级前端配置
    GPS L1C                   IF 为 2 MHz，滤波器总带宽为 3 MHz，采样率为
                              8 MHz。
    BDS B1C                   IF 为 4 MHz，滤波器总带宽为 5 MHz，采样率为
                              16 MHz。
    BDS B2a                   IF 为 15 MHz，滤波器总带宽为 25 MHz，采样率为
                              60 MHz。
    BDS B2b                   IF 为 15 MHz，滤波器总带宽为 25 MHz，采样率为
                              60 MHz。

重要译码配置
    settings.maxIterations    最大译码迭代次数。
    settings.nmEms            EMS 每条消息保留的候选数量。
    settings.alpha            MS/EMS 归一化系数。
    settings.offset           MS/EMS 偏置系数。
    settings.numTrials        每个 C/N0 点的独立蒙特卡洛帧数。
    settings.cn0Range         仿真的载噪比范围。

译码器支持通过校验后提前终止，因此平均迭代次数表示实际执行的迭代次数，并不总是等于 settings.maxIterations。比较运行时间时，应明确是否包含并行池启动、波形生成和绘图时间。


Model-Driven Training
-------------------------------------------------------------------------------
模型驱动译码器将 MS 或 EMS 的迭代过程展开，并通过显式 MATLAB 梯度计算和Adam 更新学习缩放或阻尼参数。相关入口脚本通常使用 doTraining 选择训练或推理：

    doTraining = true;        % 训练并保存新权重
    doTraining = false;       % 加载预训练权重

训练/测试入口的当前默认值如下，四条处理链均使用 `SYMBOL_LEVEL`：

| 入口脚本 | `messageType` | `doTraining` |
| --- | --- | --- |
| `GPS/NMSTrain/neuralMsGPSDemo.m` | `L1C_2` | `false` |
| `GPS/SNMS/neuralMsGPSDemo.m` | `L1C_2` | `true` |
| `BDS/NEMSTRAIN/neuralEmsDemo.m` | `B2b` | `false` |
| `BDS/SNEMSTRAIN/ShareNeuralEmsDemo.m` | `B2a` | `false` |

训练前应核对信号类型、训练 C/N0 范围、epoch 数、最大迭代次数、随机种子和输出权重文件名。每个训练目录均包含自身的配置与译码函数，不要把无关算法目录同时加入 MATLAB 路径。


Recorded-Signal Processing
-------------------------------------------------------------------------------
本仓库不包含原始 IF/IQ 录制文件。运行真实信号接收机前，应在对应
initSettings.m 中配置文件名、数据类型、实数/IQ 文件格式、中频、采样率、处理时长和相关器后端。

GPS L1C

    cd(fullfile(toolboxRoot, 'Live_Signal_Demo', 'GPS_L1C'));
    init

BDS-3 B2b

    cd(fullfile(toolboxRoot, 'Live_Signal_Demo', 'BDS-3_B2b'));
    init

接收机当前默认值位于各自的 `initSettings.m`：

| 配置项 | GPS L1C | BDS-3 B2b |
| --- | --- | --- |
| `fileName`（应替换为自己的录制文件） | `D:\xiangze\GPS L1C.iq` | `D:\xiangze\BDS_B2I_B2b.bin` |
| `dataType` / `fileType` | `int8` / `2`（交错 I/Q） | `int16` / `2`（交错 I/Q） |
| `IF` / `samplingFreq` | `0` / `25e6` Hz | `0` / `30e6` Hz |
| `msToProcess` / `numberOfChannels` | `40000` ms / `15` | `49000` ms / `15` |
| 捕获 | `gpuACQflag=1`，PRN `1:32` | `gpuACQflag=1`，PRN `6:58` |
| 跟踪 | `trkMode=1`（通道并行），`correlatorType=2`（GPU） | `trkMode=1`，`correlatorType=1`（SIMD），`rShiftBits=4` |
| `intTime` | `0.01` s | `0.001` s |
| LDPC 译码器 | `ldpcDecoderType='MS'`（OMS） | `decoderType='SNEMS'` |
| LDPC 迭代次数 / EMS 候选数 | `ldpcMaxIterations=15` | `maxIterations=15`，`nmEms=4` |
| 传统 MS/EMS 参数 | `ldpcMsAlpha=1`，`ldpcMsOffset=0.2` | `alpha=1.0`，`offset=0`（选择 EMS 时使用） |

两个接收机的 `trkMode` 含义不同：GPS 用它选择串行或并行通道处理，B2b 用它
选择 MATLAB/SIMD/GPU 后端。录制信号接收机配置与前述仿真前端配置相互独立。

BDS-3 B2b 录制信号处理链目前依赖已经实现的 GPU 捕获路径，除非提供有效的捕获结果。解释接收机结果前，必须保证全部 IF 配置与录制文件元数据一致。


Implementation Details
-------------------------------------------------------------------------------
各算法目录使用一致的外部译码接口。多算法比较脚本每次只动态加入一个算法目录，执行相同的编码与信道链路，保存性能指标，然后移除该目录再加载下一个译码器。由于 ldpcDecoderGPS.m、ldpcDecoderBDS.m、initLlr.m 等函数名在多个目录中
有意复用，必须保持这种目录隔离。

GPS L1C 使用二进制校验矩阵和比特域软信息；BDS B1C/B2a/B2b 使用 GF(64)
校验矩阵和多进制符号度量。公共仿真配置使用 `cn0Reference='DATA_COMPONENT'`，
C/N0 以仿真的数据分量为参考（B2b 对应 I 分量）。当前模型直接生成该分量，
没有单独可配置的数据/导频功率比例参数。

采样级实现按块处理长波形，避免在内存中保存完整帧波形。实中频信号经过复数下变频、配置的低通滤波器以及信号特定采样副本相关。有限采样、滤波和噪声估计可能相对符号级统计基线产生少量实现损耗。

录制信号接收机中的部分代码沿用 SoftGNSS 架构，并保留原始作者和许可证声明。
第三方代码及材料仍受其各自的版权和许可证约束。


Reproducibility
-------------------------------------------------------------------------------
保存 BER、FER 与运行时间结果时，建议同时记录：
* MATLAB 与各工具箱版本。
* 信号类型、仿真层级、译码器名称和完整 settings 配置。
* 随机种子、蒙特卡洛帧数和并行 worker 数。
* 最大迭代次数、EMS 候选保留数、归一化/偏置参数、提前终止策略以及神经
  权重训练范围。
* CPU、GPU、内存、操作系统和 MEX 后端。
* 运行时间是否包含编码、信道仿真、并行池启动和绘图，或仅统计 LDPC 译码。

有限试验中测得 BER 或 FER 为 0，只表示当前仿真未观察到错误，不能证明真实
错误概率为 0。


License
-------------------------------------------------------------------------------
GLDA 按 GNU General Public License 第 3 版或更高版本发布。完整条款见
./license.txt。第三方源文件与材料保留其原始声明及适用许可证。


