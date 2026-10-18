/*================================================================================
 * Filename   : simdCorrelatorReal_revised.cpp
 * Description: SIMD-accelerated correlator for tracking loops.
 *
 * Notes:
 *   1) This revised version keeps the original design choice that the internal
 *      buffers are allocated according to chSampleSize[0] with an extra margin.
 *      Per the user's constraint, this part is intentionally preserved.
 *   2) The revision focuses on improving input validation, code-phase wrapping,
 *      cleanup robustness, integer safety in accumulation, and overall code
 *      readability / maintainability.
 *
 * Authors    : Yafeng Li
 * Revised by : OpenAI ChatGPT
 *================================================================================*/

#include "mex.h"
#include <math.h>
#include <stdint.h>
#include <limits.h>
#include <string.h>

/* ------- SIMD ------- */
#include <emmintrin.h>
#include <tmmintrin.h>
#include <immintrin.h>

/* Function declaration --------------------------------------------------------- */
static void mixCarrReal(const short* rawSignal, double carrPhaseStep, double remCarrPhase,
                        mwSize blksize, short* iBasebandSignal, short* qBasebandSignal);
static void mixCarrComplex(const short* rawSignalI, const short* rawSignalQ,
                           double carrPhaseStep, double remCarrPhase, mwSize blksize,
                           short* iBasebandSignal, short* qBasebandSignal);
static void localCodeGen(const short* caCode, mwSize codeLen, double remCodePhase,
                         double codePhaseStep, double earlyLateSpc, mwSize blksize,
                         short** localCode);
static void correlator(const short* iBasebandSignal, const short* qBasebandSignal,
                       short** localCode, mwSize blksize, double* corrValues);
static void cleanup(void);
static double wrapPhaseDouble(double x, double period);
static int wrapIndexInt(int idx, int mod);
static void requireInputCount(int nlhs, int nrhs);
static void validateInputs(const mxArray* prhs[]);
static void* checkedMalloc(size_t bytes, const char* name);
static void initCarrierTable(char cost[16], char sint[16]);

/* Constants -------------------------------------------------------------------- */
#define PI          3.14159265358979323846
#define DPI         (2.0 * PI)
#define CSCALE      (1.0 / 16.0)
#define LOCAL_BUF_MARGIN 100
#define CORR_FLUSH_ITERS 1024

/* Persistent variables --------------------------------------------------------- */
static int initialized = 0;
static short* iBasebandSignal = NULL;
static short* qBasebandSignal = NULL;
static short* rawSignalI = NULL;
static short* rawSignalQ = NULL;
static short** localCode = NULL;

static mwSize g_channelCnt = 0;
static mwSize g_codeLen = 0;
static int g_fileType = 0;
static mwSize g_sampleIQSize = 0;
static mwSize g_allocBlkSize = 0;
static mwSize g_rawSignalElements = 0;

/* The gateway function ---------------------------------------------------------
 * Args   : short   *rawSignal         I   Input IF signal
 *          short   *caCodeTable       I   GPS L1 PRN code sequence lookup table
 *          double  *remCarrPhase      I   Residual carrier phase for each channel (rad)
 *          double  *carrPhaseStep     I   Carrier phase step for each sample (rad/sample)
 *          double  *remCodePhase      I   Residual code phase for each channel (chips)
 *          double  *codePhaseStep     I   Code phase step for each sample (chips/sample)
 *          double   earlyLateSpc      I   Half of the early-late spacing (chips)
 *          int32   *startIndex        I   Start sample index for each channel (1-based)
 *          int32   *chSampleSize      I   Number of samples processed for each channel
 *          int      dataReadFlag      I   Data-read flag (1: read new data, 0: reuse previous)
 *          int      fileType          I   Input signal type (1: real, 2: complex IQ interleaved)
 *          double  *corrValues        O   Correlator outputs (IE QE IP QP IL QL)
 * Return : double  *corrValues
 *------------------------------------------------------------------------------*/
void mexFunction(int nlhs, mxArray* plhs[], int nrhs, const mxArray* prhs[])
{
    /* Input pointers */
    short* rawSignal = NULL;
    short* caCodeTable = NULL;
    int32_T* startIndex = NULL;
    int32_T* chSampleSize = NULL;
    double* remCarrPhase = NULL;
    double* carrPhaseStep = NULL;
    double* remCodePhase = NULL;
    double* codePhaseStep = NULL;
    double earlyLateSpc = 0.0;
    double* corrValues = NULL;

    requireInputCount(nlhs, nrhs);
    validateInputs(prhs);

    rawSignal = (short*)mxGetData(prhs[0]);
    caCodeTable = (short*)mxGetData(prhs[1]);
    remCarrPhase = mxGetPr(prhs[2]);
    carrPhaseStep = mxGetPr(prhs[3]);
    remCodePhase = mxGetPr(prhs[4]);
    codePhaseStep = mxGetPr(prhs[5]);
    earlyLateSpc = mxGetScalar(prhs[6]);
    startIndex = (int32_T*)mxGetData(prhs[7]);
    chSampleSize = (int32_T*)mxGetData(prhs[8]);
    const int dataReadFlag = (int)mxGetScalar(prhs[9]);
    const int fileType = (int)mxGetScalar(prhs[10]);

    const mwSize codeLen = mxGetM(prhs[1]);
    const mwSize channelCnt = mxGetN(prhs[1]);
    const mwSize rawSignalElements = mxGetNumberOfElements(prhs[0]);
    const mwSize blksize = (mwSize)chSampleSize[0]; /* Intentionally preserved by request */

    if (!initialized)
    {
        g_channelCnt = channelCnt;
        g_codeLen = codeLen;
        g_fileType = fileType;
        g_allocBlkSize = blksize + LOCAL_BUF_MARGIN;
        g_rawSignalElements = rawSignalElements;

        if (g_fileType == 2)
        {
            if ((rawSignalElements & 1u) != 0u)
            {
                mexErrMsgIdAndTxt("simdCorr:Input", "For fileType = 2, rawSignal must contain an even number of elements.");
            }
            g_sampleIQSize = rawSignalElements / 2;
            rawSignalI = (short*)checkedMalloc(sizeof(short) * g_sampleIQSize, "rawSignalI");
            rawSignalQ = (short*)checkedMalloc(sizeof(short) * g_sampleIQSize, "rawSignalQ");
        }

        iBasebandSignal = (short*)checkedMalloc(sizeof(short) * g_allocBlkSize, "iBasebandSignal");
        qBasebandSignal = (short*)checkedMalloc(sizeof(short) * g_allocBlkSize, "qBasebandSignal");

        localCode = (short**)checkedMalloc(sizeof(short*) * 3, "localCode");
        for (int i = 0; i < 3; ++i)
        {
            localCode[i] = (short*)checkedMalloc(sizeof(short) * g_allocBlkSize, "localCode[i]");
        }

        mexAtExit(cleanup);
        initialized = 1;
        mexPrintf("[simdCorr] MEX-file initialized.\n");
    }
    else
    {
        if (channelCnt != g_channelCnt)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "channelCnt changed after initialization. Clear MEX and reinitialize.");
        }
        if (codeLen != g_codeLen)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "codeLen changed after initialization. Clear MEX and reinitialize.");
        }
        if (fileType != g_fileType)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "fileType changed after initialization. Clear MEX and reinitialize.");
        }
        if (rawSignalElements != g_rawSignalElements)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "rawSignal length changed after initialization. Clear MEX and reinitialize.");
        }
    }

    for (mwSize chInd = 0; chInd < channelCnt; ++chInd)
    {
        if (startIndex[chInd] < 1)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "startIndex must be 1-based and >= 1.");
        }
        if (chSampleSize[chInd] <= 0)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "All chSampleSize values must be positive.");
        }
        if ((mwSize)chSampleSize[chInd] > g_allocBlkSize)
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "A chSampleSize value exceeds the preserved internal buffer size.");
        }

        if (fileType == 1)
        {
            const mwSize endPos = (mwSize)(startIndex[chInd] - 1) + (mwSize)chSampleSize[chInd];
            if (endPos > rawSignalElements)
            {
                mexErrMsgIdAndTxt("simdCorr:Input", "Real rawSignal access exceeds input length.");
            }
        }
        else
        {
            const mwSize endPos = (mwSize)(startIndex[chInd] - 1) + (mwSize)chSampleSize[chInd];
            if (endPos > g_sampleIQSize)
            {
                mexErrMsgIdAndTxt("simdCorr:Input", "Complex rawSignal access exceeds IQ branch length.");
            }
        }
    }

    plhs[0] = mxCreateDoubleMatrix((mwSize)6, channelCnt, mxREAL);
    corrValues = mxGetPr(plhs[0]);

    if (dataReadFlag == 1 && fileType == 2)
    {
        short* IFDataI = rawSignalI;
        short* IFDataQ = rawSignalQ;
        const short* IFData = rawSignal;
        for (mwSize n = 0; n < g_sampleIQSize; ++n, ++IFDataI, ++IFDataQ, IFData += 2)
        {
            IFDataI[0] = IFData[0];
            IFDataQ[0] = IFData[1];
        }
    }

    mwIndex dims[2] = {0, 0};
    for (mwIndex chInd = 0; chInd < (mwIndex)channelCnt; ++chInd)
    {
        dims[1] = chInd;
        const size_t index = mxCalcSingleSubscript(prhs[1], 2, dims);
        const short* caCode = &caCodeTable[index];

        if (fileType == 1)
        {
            mixCarrReal(rawSignal + startIndex[chInd] - 1,
                        carrPhaseStep[chInd], remCarrPhase[chInd],
                        (mwSize)chSampleSize[chInd], iBasebandSignal, qBasebandSignal);
        }
        else
        {
            mixCarrComplex(rawSignalI + startIndex[chInd] - 1,
                           rawSignalQ + startIndex[chInd] - 1,
                           carrPhaseStep[chInd], remCarrPhase[chInd],
                           (mwSize)chSampleSize[chInd], iBasebandSignal, qBasebandSignal);
        }

        localCodeGen(caCode, g_codeLen, remCodePhase[chInd],
                     codePhaseStep[chInd], earlyLateSpc,
                     (mwSize)chSampleSize[chInd], localCode);

        correlator(iBasebandSignal, qBasebandSignal, localCode,
                   (mwSize)chSampleSize[chInd], corrValues + 6 * chInd);
    }
}

/* Mix local carrier for real data ---------------------------------------------- */
static void mixCarrReal(const short* rawSignal, double carrPhaseStep, double remCarrPhase, mwSize blksize,
                        short* iBasebandSignal, short* qBasebandSignal)
{
    const short* IFData = NULL;
    double phaseStep = carrPhaseStep / DPI * 16.0;
    static char cost[16] = {0};
    static char sint[16] = {0};

    if (!cost[0])
    {
        initCarrierTable(cost, sint);
    }

    remCarrPhase = remCarrPhase * 16.0 / DPI;

    __m256i Index_mm256, Index_reg1, Index_reg2, cos_reg_mm256, sin_reg_mm256, IF_reg, iBaseband_reg, qBaseband_reg;
    __m256 carrPhase_reg1, carrPhase_reg2;
    __m128i Index_reg, cos_reg_mm128, sin_reg_mm128;
    __m256 stepNumber_reg = _mm256_set_ps(11.0f, 10.0f, 9.0f, 8.0f, 3.0f, 2.0f, 1.0f, 0.0f);
    const __m256 remCarrPhase_reg = _mm256_set1_ps((float)remCarrPhase);
    const __m256 carrPhaseStep_reg = _mm256_set1_ps((float)phaseStep);
    const __m256i mask4 = _mm256_set1_epi32(15);
    const __m256 sixteenStep = _mm256_set1_ps(16.0f);
    const __m256 fourPhase = _mm256_set1_ps((float)(phaseStep * 4.0));
    const __m128i local_cos = _mm_loadu_si128((const __m128i*)cost);
    const __m128i local_sin = _mm_loadu_si128((const __m128i*)sint);
    const __m256i mask_16_to_8 = _mm256_set_epi8(
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x0E, 0x0C, 0x0A, 0x08, 0x06, 0x04, 0x02, 0x00,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x0E, 0x0C, 0x0A, 0x08, 0x06, 0x04, 0x02, 0x00);

    for (IFData = rawSignal; IFData <= rawSignal + blksize - 16; IFData += 16, iBasebandSignal += 16, qBasebandSignal += 16)
    {
        carrPhase_reg1 = _mm256_fmadd_ps(carrPhaseStep_reg, stepNumber_reg, remCarrPhase_reg);
        carrPhase_reg2 = _mm256_add_ps(carrPhase_reg1, fourPhase);

        Index_reg1 = _mm256_cvtps_epi32(carrPhase_reg1);
        Index_reg1 = _mm256_and_si256(Index_reg1, mask4);
        Index_reg2 = _mm256_cvtps_epi32(carrPhase_reg2);
        Index_reg2 = _mm256_and_si256(Index_reg2, mask4);

        Index_mm256 = _mm256_packs_epi32(Index_reg1, Index_reg2);
        Index_mm256 = _mm256_shuffle_epi8(Index_mm256, mask_16_to_8);
        Index_mm256 = _mm256_permute4x64_epi64(Index_mm256, 0x58);
        Index_reg = _mm256_castsi256_si128(Index_mm256);

        cos_reg_mm128 = _mm_shuffle_epi8(local_cos, Index_reg);
        sin_reg_mm128 = _mm_shuffle_epi8(local_sin, Index_reg);

        cos_reg_mm256 = _mm256_cvtepi8_epi16(cos_reg_mm128);
        sin_reg_mm256 = _mm256_cvtepi8_epi16(sin_reg_mm128);

        IF_reg = _mm256_loadu_si256((const __m256i*)IFData);
        iBaseband_reg = _mm256_mullo_epi16(IF_reg, sin_reg_mm256);
        qBaseband_reg = _mm256_mullo_epi16(IF_reg, cos_reg_mm256);

        _mm256_storeu_si256((__m256i*)iBasebandSignal, iBaseband_reg);
        _mm256_storeu_si256((__m256i*)qBasebandSignal, qBaseband_reg);

        stepNumber_reg = _mm256_add_ps(stepNumber_reg, sixteenStep);
    }

    remCarrPhase = (blksize / 16) * 16 * phaseStep + remCarrPhase;
    for (; IFData < rawSignal + blksize; ++IFData, ++iBasebandSignal, ++qBasebandSignal)
    {
        const int n = wrapIndexInt((int)remCarrPhase, 16);
        iBasebandSignal[0] = (short)(sint[n] * IFData[0]);
        qBasebandSignal[0] = (short)(cost[n] * IFData[0]);
        remCarrPhase += phaseStep;
    }
}

/* Mix local carrier for complex data ------------------------------------------- */
static void mixCarrComplex(const short* rawSignalI, const short* rawSignalQ,
                           double carrPhaseStep, double remCarrPhase, mwSize blksize,
                           short* iBasebandSignal, short* qBasebandSignal)
{
    const short* IFDataI = NULL;
    const short* IFDataQ = NULL;
    double phaseStep = carrPhaseStep / DPI * 16.0;
    static char cost[16] = {0};
    static char sint[16] = {0};

    if (!cost[0])
    {
        initCarrierTable(cost, sint);
    }

    remCarrPhase = remCarrPhase * 16.0 / DPI;

    __m256i Index_mm256, Index_reg1, Index_reg2, cos_reg_mm256, sin_reg_mm256, IF_regI, IF_regQ;
    __m256i iBaseband_regI, qBaseband_regI, iBaseband_regQ, qBaseband_regQ, iBaseband_reg, qBaseband_reg;
    __m256 carrPhase_reg1, carrPhase_reg2;
    __m128i Index_reg, cos_reg_mm128, sin_reg_mm128;
    __m256 stepNumber_reg = _mm256_set_ps(11.0f, 10.0f, 9.0f, 8.0f, 3.0f, 2.0f, 1.0f, 0.0f);
    const __m256 remCarrPhase_reg = _mm256_set1_ps((float)remCarrPhase);
    const __m256 carrPhaseStep_reg = _mm256_set1_ps((float)phaseStep);
    const __m256i mask4 = _mm256_set1_epi32(15);
    const __m256 sixteenStep = _mm256_set1_ps(16.0f);
    const __m256 fourPhase = _mm256_set1_ps((float)(phaseStep * 4.0));
    const __m128i local_cos = _mm_loadu_si128((const __m128i*)cost);
    const __m128i local_sin = _mm_loadu_si128((const __m128i*)sint);
    const __m256i mask_16_to_8 = _mm256_set_epi8(
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x0E, 0x0C, 0x0A, 0x08, 0x06, 0x04, 0x02, 0x00,
        0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01, 0x01,
        0x0E, 0x0C, 0x0A, 0x08, 0x06, 0x04, 0x02, 0x00);

    for (IFDataI = rawSignalI, IFDataQ = rawSignalQ;
         IFDataI <= rawSignalI + blksize - 16;
         IFDataI += 16, IFDataQ += 16, iBasebandSignal += 16, qBasebandSignal += 16)
    {
        carrPhase_reg1 = _mm256_fmadd_ps(carrPhaseStep_reg, stepNumber_reg, remCarrPhase_reg);
        carrPhase_reg2 = _mm256_add_ps(carrPhase_reg1, fourPhase);

        Index_reg1 = _mm256_cvtps_epi32(carrPhase_reg1);
        Index_reg1 = _mm256_and_si256(Index_reg1, mask4);
        Index_reg2 = _mm256_cvtps_epi32(carrPhase_reg2);
        Index_reg2 = _mm256_and_si256(Index_reg2, mask4);

        Index_mm256 = _mm256_packs_epi32(Index_reg1, Index_reg2);
        Index_mm256 = _mm256_shuffle_epi8(Index_mm256, mask_16_to_8);
        Index_mm256 = _mm256_permute4x64_epi64(Index_mm256, 0x58);
        Index_reg = _mm256_castsi256_si128(Index_mm256);

        cos_reg_mm128 = _mm_shuffle_epi8(local_cos, Index_reg);
        sin_reg_mm128 = _mm_shuffle_epi8(local_sin, Index_reg);

        cos_reg_mm256 = _mm256_cvtepi8_epi16(cos_reg_mm128);
        sin_reg_mm256 = _mm256_cvtepi8_epi16(sin_reg_mm128);

        IF_regI = _mm256_loadu_si256((const __m256i*)IFDataI);
        IF_regQ = _mm256_loadu_si256((const __m256i*)IFDataQ);

        iBaseband_regI = _mm256_mullo_epi16(IF_regI, sin_reg_mm256);
        qBaseband_regI = _mm256_mullo_epi16(IF_regI, cos_reg_mm256);
        iBaseband_regQ = _mm256_mullo_epi16(IF_regQ, sin_reg_mm256);
        qBaseband_regQ = _mm256_mullo_epi16(IF_regQ, cos_reg_mm256);

        iBaseband_reg = _mm256_add_epi16(qBaseband_regQ, iBaseband_regI);
        qBaseband_reg = _mm256_sub_epi16(qBaseband_regI, iBaseband_regQ);

        _mm256_storeu_si256((__m256i*)iBasebandSignal, iBaseband_reg);
        _mm256_storeu_si256((__m256i*)qBasebandSignal, qBaseband_reg);

        stepNumber_reg = _mm256_add_ps(stepNumber_reg, sixteenStep);
    }

    remCarrPhase = (blksize / 16) * 16 * phaseStep + remCarrPhase;
    for (; IFDataI < rawSignalI + blksize; ++IFDataI, ++IFDataQ, ++iBasebandSignal, ++qBasebandSignal)
    {
        const int n = wrapIndexInt((int)remCarrPhase, 16);
        iBasebandSignal[0] = (short)(sint[n] * IFDataI[0] + cost[n] * IFDataQ[0]);
        qBasebandSignal[0] = (short)(cost[n] * IFDataI[0] - sint[n] * IFDataQ[0]);
        remCarrPhase += phaseStep;
    }
}

/* Generate local early / prompt / late code replicas --------------------------- */
static void localCodeGen(const short* caCode, mwSize codeLen, double remCodePhase,
                         double codePhaseStep, double earlyLateSpc, mwSize blksize,
                         short** localCode)
{
    const int codeLenInt = (int)codeLen;
    remCodePhase = wrapPhaseDouble(remCodePhase - earlyLateSpc + 1.0, (double)codeLenInt);

    short* pE = localCode[0];
    short* pP = localCode[1];
    short* pL = localCode[2];
    int index[16];

    __m256i Index_reg1, Index_reg2;
    __m256 codePhase_reg1, codePhase_reg2;
    __m256 stepNumber_reg = _mm256_set_ps(7.0f, 6.0f, 5.0f, 4.0f, 3.0f, 2.0f, 1.0f, 0.0f);
    const __m256 remCodePhase_reg = _mm256_set1_ps((float)remCodePhase);
    const __m256 codePhaseStep_reg = _mm256_set1_ps((float)codePhaseStep);
    const __m256 earlyLateSpc_reg = _mm256_set1_ps((float)earlyLateSpc);
    const __m256 sixteenStep = _mm256_set1_ps(16.0f);
    const __m256 eightCodePhase = _mm256_set1_ps((float)(codePhaseStep * 8.0));

    for (; pE <= localCode[0] + blksize - 16; pE += 16, pP += 16, pL += 16)
    {
        codePhase_reg1 = _mm256_fmadd_ps(codePhaseStep_reg, stepNumber_reg, remCodePhase_reg);
        codePhase_reg2 = _mm256_add_ps(codePhase_reg1, eightCodePhase);
        Index_reg1 = _mm256_cvttps_epi32(codePhase_reg1);
        Index_reg2 = _mm256_cvttps_epi32(codePhase_reg2);
        _mm256_storeu_si256((__m256i*)index, Index_reg1);
        _mm256_storeu_si256((__m256i*)(index + 8), Index_reg2);
        for (int i = 0; i < 16; ++i)
        {
            pE[i] = caCode[wrapIndexInt(index[i], codeLenInt)];
        }

        codePhase_reg1 = _mm256_add_ps(codePhase_reg1, earlyLateSpc_reg);
        codePhase_reg2 = _mm256_add_ps(codePhase_reg2, earlyLateSpc_reg);
        Index_reg1 = _mm256_cvttps_epi32(codePhase_reg1);
        Index_reg2 = _mm256_cvttps_epi32(codePhase_reg2);
        _mm256_storeu_si256((__m256i*)index, Index_reg1);
        _mm256_storeu_si256((__m256i*)(index + 8), Index_reg2);
        for (int i = 0; i < 16; ++i)
        {
            pP[i] = caCode[wrapIndexInt(index[i], codeLenInt)];
        }

        codePhase_reg1 = _mm256_add_ps(codePhase_reg1, earlyLateSpc_reg);
        codePhase_reg2 = _mm256_add_ps(codePhase_reg2, earlyLateSpc_reg);
        Index_reg1 = _mm256_cvttps_epi32(codePhase_reg1);
        Index_reg2 = _mm256_cvttps_epi32(codePhase_reg2);
        _mm256_storeu_si256((__m256i*)index, Index_reg1);
        _mm256_storeu_si256((__m256i*)(index + 8), Index_reg2);
        for (int i = 0; i < 16; ++i)
        {
            pL[i] = caCode[wrapIndexInt(index[i], codeLenInt)];
        }

        stepNumber_reg = _mm256_add_ps(stepNumber_reg, sixteenStep);
    }

    double corrCodePhase = wrapPhaseDouble((blksize / 16) * 16 * codePhaseStep + remCodePhase, (double)codeLenInt);
    const double twoEarlyLateSpc = earlyLateSpc * 2.0;
    for (; pE < localCode[0] + blksize; ++pE, ++pP, ++pL)
    {
        pE[0] = caCode[wrapIndexInt((int)corrCodePhase, codeLenInt)];
        pP[0] = caCode[wrapIndexInt((int)(corrCodePhase + earlyLateSpc), codeLenInt)];
        pL[0] = caCode[wrapIndexInt((int)(corrCodePhase + twoEarlyLateSpc), codeLenInt)];
        corrCodePhase = wrapPhaseDouble(corrCodePhase + codePhaseStep, (double)codeLenInt);
    }
}

/* Correlator ------------------------------------------------------------------- */
static void correlator(const short* iBasebandSignal, const short* qBasebandSignal,
                       short** localCode, mwSize blksize, double* corrValues)
{
    int32_t I_E_sum[8], I_P_sum[8], I_L_sum[8], Q_E_sum[8], Q_P_sum[8], Q_L_sum[8];
    int64_t I_E = 0, I_P = 0, I_L = 0, Q_E = 0, Q_P = 0, Q_L = 0;
    const short* pI = iBasebandSignal;
    const short* pQ = qBasebandSignal;
    short* pE = localCode[0];
    short* pP = localCode[1];
    short* pL = localCode[2];

    __m256i I_reg, Q_reg, I_E_reg, I_P_reg, I_L_reg, Q_E_reg, Q_P_reg, Q_L_reg, EPL_reg, mul_reg;
    I_E_reg = _mm256_setzero_si256();
    I_P_reg = _mm256_setzero_si256();
    I_L_reg = _mm256_setzero_si256();
    Q_E_reg = _mm256_setzero_si256();
    Q_P_reg = _mm256_setzero_si256();
    Q_L_reg = _mm256_setzero_si256();

    int flushCounter = 0;
    for (; pE <= localCode[0] + blksize - 16; pE += 16, pP += 16, pL += 16, pI += 16, pQ += 16)
    {
        I_reg = _mm256_loadu_si256((const __m256i*)pI);
        Q_reg = _mm256_loadu_si256((const __m256i*)pQ);

        EPL_reg = _mm256_loadu_si256((const __m256i*)pE);
        mul_reg = _mm256_madd_epi16(I_reg, EPL_reg);
        I_E_reg = _mm256_add_epi32(I_E_reg, mul_reg);
        mul_reg = _mm256_madd_epi16(Q_reg, EPL_reg);
        Q_E_reg = _mm256_add_epi32(Q_E_reg, mul_reg);

        EPL_reg = _mm256_loadu_si256((const __m256i*)pP);
        mul_reg = _mm256_madd_epi16(I_reg, EPL_reg);
        I_P_reg = _mm256_add_epi32(I_P_reg, mul_reg);
        mul_reg = _mm256_madd_epi16(Q_reg, EPL_reg);
        Q_P_reg = _mm256_add_epi32(Q_P_reg, mul_reg);

        EPL_reg = _mm256_loadu_si256((const __m256i*)pL);
        mul_reg = _mm256_madd_epi16(I_reg, EPL_reg);
        I_L_reg = _mm256_add_epi32(I_L_reg, mul_reg);
        mul_reg = _mm256_madd_epi16(Q_reg, EPL_reg);
        Q_L_reg = _mm256_add_epi32(Q_L_reg, mul_reg);

        ++flushCounter;
        if (flushCounter >= CORR_FLUSH_ITERS)
        {
            _mm256_storeu_si256((__m256i*)I_E_sum, I_E_reg);
            _mm256_storeu_si256((__m256i*)Q_E_sum, Q_E_reg);
            _mm256_storeu_si256((__m256i*)I_P_sum, I_P_reg);
            _mm256_storeu_si256((__m256i*)Q_P_sum, Q_P_reg);
            _mm256_storeu_si256((__m256i*)I_L_sum, I_L_reg);
            _mm256_storeu_si256((__m256i*)Q_L_sum, Q_L_reg);
            for (int i = 0; i < 8; ++i)
            {
                I_E += I_E_sum[i]; Q_E += Q_E_sum[i];
                I_P += I_P_sum[i]; Q_P += Q_P_sum[i];
                I_L += I_L_sum[i]; Q_L += Q_L_sum[i];
            }
            I_E_reg = _mm256_setzero_si256();
            I_P_reg = _mm256_setzero_si256();
            I_L_reg = _mm256_setzero_si256();
            Q_E_reg = _mm256_setzero_si256();
            Q_P_reg = _mm256_setzero_si256();
            Q_L_reg = _mm256_setzero_si256();
            flushCounter = 0;
        }
    }

    _mm256_storeu_si256((__m256i*)I_E_sum, I_E_reg);
    _mm256_storeu_si256((__m256i*)Q_E_sum, Q_E_reg);
    _mm256_storeu_si256((__m256i*)I_P_sum, I_P_reg);
    _mm256_storeu_si256((__m256i*)Q_P_sum, Q_P_reg);
    _mm256_storeu_si256((__m256i*)I_L_sum, I_L_reg);
    _mm256_storeu_si256((__m256i*)Q_L_sum, Q_L_reg);
    for (int i = 0; i < 8; ++i)
    {
        I_E += I_E_sum[i]; Q_E += Q_E_sum[i];
        I_P += I_P_sum[i]; Q_P += Q_P_sum[i];
        I_L += I_L_sum[i]; Q_L += Q_L_sum[i];
    }

    for (; pE < localCode[0] + blksize; ++pI, ++pQ, ++pE, ++pP, ++pL)
    {
        I_E += (int64_t)pI[0] * pE[0]; Q_E += (int64_t)pQ[0] * pE[0];
        I_P += (int64_t)pI[0] * pP[0]; Q_P += (int64_t)pQ[0] * pP[0];
        I_L += (int64_t)pI[0] * pL[0]; Q_L += (int64_t)pQ[0] * pL[0];
    }

    corrValues[0] = (double)I_E * CSCALE; corrValues[1] = (double)Q_E * CSCALE;
    corrValues[2] = (double)I_P * CSCALE; corrValues[3] = (double)Q_P * CSCALE;
    corrValues[4] = (double)I_L * CSCALE; corrValues[5] = (double)Q_L * CSCALE;
}

/* Cleanup ---------------------------------------------------------------------- */
static void cleanup(void)
{
    mexPrintf("[simdCorr] MEX-file is terminating, destroying allocated memory...\n");

    if (localCode != NULL)
    {
        for (int i = 0; i < 3; ++i)
        {
            if (localCode[i] != NULL)
            {
                free(localCode[i]);
                localCode[i] = NULL;
            }
        }
        free(localCode);
        localCode = NULL;
    }

    if (iBasebandSignal != NULL) { free(iBasebandSignal); iBasebandSignal = NULL; }
    if (qBasebandSignal != NULL) { free(qBasebandSignal); qBasebandSignal = NULL; }
    if (rawSignalI != NULL) { free(rawSignalI); rawSignalI = NULL; }
    if (rawSignalQ != NULL) { free(rawSignalQ); rawSignalQ = NULL; }

    initialized = 0;
    g_channelCnt = 0;
    g_codeLen = 0;
    g_fileType = 0;
    g_sampleIQSize = 0;
    g_allocBlkSize = 0;
    g_rawSignalElements = 0;
}

/* Helpers ---------------------------------------------------------------------- */
static double wrapPhaseDouble(double x, double period)
{
    if (period <= 0.0)
    {
        return x;
    }
    x = fmod(x, period);
    if (x < 0.0)
    {
        x += period;
    }
    return x;
}

static int wrapIndexInt(int idx, int mod)
{
    if (mod <= 0)
    {
        return idx;
    }
    idx %= mod;
    if (idx < 0)
    {
        idx += mod;
    }
    return idx;
}

static void requireInputCount(int nlhs, int nrhs)
{
    if (nrhs != 11)
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "simdCorrelatorReal requires exactly 11 input arguments.");
    }
    if (nlhs > 1)
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "simdCorrelatorReal returns exactly one output argument.");
    }
}

static void validateInputs(const mxArray* prhs[])
{
    if (!mxIsInt16(prhs[0]) || mxIsComplex(prhs[0]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "rawSignal must be a real int16 array.");
    }
    if (!mxIsInt16(prhs[1]) || mxIsComplex(prhs[1]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "caCodeTable must be a real int16 matrix.");
    }

    for (int k = 2; k <= 5; ++k)
    {
        if (!mxIsDouble(prhs[k]) || mxIsComplex(prhs[k]))
        {
            mexErrMsgIdAndTxt("simdCorr:Input", "Phase-related inputs must be real double arrays.");
        }
    }

    if (!mxIsDouble(prhs[6]) || !mxIsScalar(prhs[6]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "earlyLateSpc must be a real double scalar.");
    }
    if (!mxIsInt32(prhs[7]) || mxIsComplex(prhs[7]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "startIndex must be a real int32 array.");
    }
    if (!mxIsInt32(prhs[8]) || mxIsComplex(prhs[8]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "chSampleSize must be a real int32 array.");
    }
    if (!mxIsDouble(prhs[9]) || !mxIsScalar(prhs[9]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "dataReadFlag must be a scalar.");
    }
    if (!mxIsDouble(prhs[10]) || !mxIsScalar(prhs[10]))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "fileType must be a scalar.");
    }

    const mwSize channelCnt = mxGetN(prhs[1]);
    if (mxGetNumberOfElements(prhs[2]) != channelCnt ||
        mxGetNumberOfElements(prhs[3]) != channelCnt ||
        mxGetNumberOfElements(prhs[4]) != channelCnt ||
        mxGetNumberOfElements(prhs[5]) != channelCnt ||
        mxGetNumberOfElements(prhs[7]) != channelCnt ||
        mxGetNumberOfElements(prhs[8]) != channelCnt)
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "Per-channel inputs must all have channelCnt elements.");
    }

    const int fileType = (int)mxGetScalar(prhs[10]);
    if (!(fileType == 1 || fileType == 2))
    {
        mexErrMsgIdAndTxt("simdCorr:Input", "fileType must be 1 (real) or 2 (complex IQ interleaved).");
    }
}

static void* checkedMalloc(size_t bytes, const char* name)
{
    void* p = malloc(bytes);
    if (p == NULL)
    {
        mexErrMsgIdAndTxt("simdCorr:Memory", "Failed to allocate memory for %s.", name);
    }
    memset(p, 0, bytes);
    return p;
}

static void initCarrierTable(char cost[16], char sint[16])
{
    for (int i = 0; i < 16; ++i)
    {
        cost[i] = (char)floor(cos(PI / 8.0 * i) / CSCALE + 0.5);
        sint[i] = (char)floor(sin(PI / 8.0 * i) / CSCALE + 0.5);
    }
}
