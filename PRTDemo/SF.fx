//-----------------------------------------------------------------------------
// File: SF.fx
//
// Desc: The technique Precomputed Shadow Fields renders the scene with per vertex PRT
// 
// Copyright (c) Tao LIN. All rights reserved.
//-----------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// Global variables
//-----------------------------------------------------------------------------
float4x4 g_mWorldViewProjection;
texture AlbedoTexture;
texture OOFTex;
texture OOFTex2;
//Texture2D<float> OOFTex: register(t0);
//SamplerState OOFTexSampler : register(s0);


#define NUM_CHANNELS	3

#define BALLNUM 2
#define SPHERENUM 20
#define LATNUM 16
#define LNGNUM 16
//#define SPHERENUM 16
//#define LATNUM 8
//#define LNGNUM 8
//#define SPHERENUM 8
//#define LATNUM 4
//#define LNGNUM 4
#define DIST_NEAR 0.2f
#define DIST_FAR 8.0f
#define TEXWIDTH 128

// The values for NUM_CLUSTERS, NUM_PCA and NUM_COEFFS are
// defined by the app upon the D3DXCreateEffectFromFile() call.

//float4 aPRTConstants[NUM_CLUSTERS*(1 + NUM_CHANNELS*(NUM_PCA / 4))];
float aPRTClusterBases[((NUM_PCA + 1) * NUM_COEFFS * NUM_CHANNELS)*NUM_CLUSTERS];
//float aOOFBuffer[LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS];
//float aOOFBuffer2[LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS];
float aEnvSHCoeffs[NUM_COEFFS * 3];
float4 aBallInfo[2*BALLNUM];

float4 MaterialDiffuseColor = { 1.0f, 1.0f, 1.0f, 1.0f };

#define PI 3.14159265359f

#define SH_A a
#define SH_B b
#define SH_C TheT[colo]


//-----------------------------------------------------------------------------
sampler AlbedoSampler = sampler_state
{
    Texture = (AlbedoTexture);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler OOFTexSampler = sampler_state
{
    Texture = (OOFTex);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

sampler OOFTexSampler2 = sampler_state
{
    Texture = (OOFTex2);
    MipFilter = LINEAR;
    MinFilter = LINEAR;
    MagFilter = LINEAR;
};

//-----------------------------------------------------------------------------
// Vertex shader output structure
//-----------------------------------------------------------------------------
struct VS_OUTPUT
{
    float4 Position  : POSITION;    // position of the vertex
    float4 Diffuse   : COLOR0;      // diffuse color of the vertex
    float2 TexCoord  : TEXCOORD0;
};

struct SHProduct_OUTPUT
{
    float c[NUM_COEFFS];
};

struct twoOffsets
{
    int offset1;
    int offset2;
    float ratio;
};

float4 bitShifts = float4(1.0 / (256.0*256.0*256.0), 1.0 / (256.0*256.0), 1.0 / 256.0, 1);

float getOOFBuffer(int ppp)
{
    int nx = TEXWIDTH;
    int n = LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS;
    //int n = 8;
    //int n = 3456;
    int ny = ceil(1.0f*n/nx);
    int x = ppp%TEXWIDTH;
    int y = ppp / TEXWIDTH;
    float texOffX = 1.0f / nx*(0.5f + x);
    float texOffY = 1.0f / ny*(0.5f + y);
    float4 hello;
    float hi;

    //float hello = OOFTex.Sample(OOFTexSampler, float2(0.5f, FieldOffset + 0 * NUM_COEFFS + t + 0.5f));

    //return tex2Dlod(OOFTexSampler, float4(pos.x / 2, pos.y / 2, 0, 0));
    hello = tex2Dlod(OOFTexSampler, float4(texOffX, texOffY, 0, 0));
    //return hello;
    hi = dot(hello.argb, bitShifts);
    //return hi;
    return hi * 10.0f - 5.0f;
}

float getOOFBuffer2(int ppp)
{
    int nx = TEXWIDTH;
    int n = LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS;
    int ny = ceil(1.0f*n / nx);
    int x = ppp%TEXWIDTH;
    int y = ppp / TEXWIDTH;
    float texOffX = 1.0f / nx*(0.5f + x);
    float texOffY = 1.0f / ny*(0.5f + y);
    float4 hello;
    float hi;
    // The only difference with the code before:
    hello = tex2Dlod(OOFTexSampler2, float4(texOffX, texOffY, 0, 0));
    hi = dot(hello.argb, bitShifts);
    return hi * 10.0f - 5.0f;
}

// NUM_COEFFS must be 9 here
//Based on http://research.microsoft.com/en-us/um/people/johnsny/#shtriple
SHProduct_OUTPUT SH_product_3(float a[NUM_COEFFS], float b[NUM_COEFFS])
{
    float c[NUM_COEFFS];
    float ta, tb, t;
    // [0,0]: 0,
    c[0] = 0.282094792935999980f*a[0] * b[0];

    // [1,1]: 0,6,8,
    ta = 0.282094791773000010f*a[0] + -0.126156626101000010f*a[6] + -0.218509686119999990f*a[8];
    tb = 0.282094791773000010f*b[0] + -0.126156626101000010f*b[6] + -0.218509686119999990f*b[8];
    c[1] = ta*b[1] + tb*a[1];
    t = a[1] * b[1];
    c[0] += 0.282094791773000010f*t;
    c[6] = -0.126156626101000010f*t;
    c[8] = -0.218509686119999990f*t;

    // [1,2]: 5,
    ta = 0.218509686118000010f*a[5];
    tb = 0.218509686118000010f*b[5];
    c[1] += ta*b[2] + tb*a[2];
    c[2] = ta*b[1] + tb*a[1];
    t = a[1] * b[2] + a[2] * b[1];
    c[5] = 0.218509686118000010f*t;

    // [1,3]: 4,
    ta = 0.218509686114999990f*a[4];
    tb = 0.218509686114999990f*b[4];
    c[1] += ta*b[3] + tb*a[3];
    c[3] = ta*b[1] + tb*a[1];
    t = a[1] * b[3] + a[3] * b[1];
    c[4] = 0.218509686114999990f*t;

    // [2,2]: 0,6,
    ta = 0.282094795249000000f*a[0] + 0.252313259986999990f*a[6];
    tb = 0.282094795249000000f*b[0] + 0.252313259986999990f*b[6];
    c[2] += ta*b[2] + tb*a[2];
    t = a[2] * b[2];
    c[0] += 0.282094795249000000f*t;
    c[6] += 0.252313259986999990f*t;

    // [2,3]: 7,
    ta = 0.218509686118000010f*a[7];
    tb = 0.218509686118000010f*b[7];
    c[2] += ta*b[3] + tb*a[3];
    c[3] += ta*b[2] + tb*a[2];
    t = a[2] * b[3] + a[3] * b[2];
    c[7] = 0.218509686118000010f*t;

    // [3,3]: 0,6,8,
    ta = 0.282094791773000010f*a[0] + -0.126156626101000010f*a[6] + 0.218509686119999990f*a[8];
    tb = 0.282094791773000010f*b[0] + -0.126156626101000010f*b[6] + 0.218509686119999990f*b[8];
    c[3] += ta*b[3] + tb*a[3];
    t = a[3] * b[3];
    c[0] += 0.282094791773000010f*t;
    c[6] += -0.126156626101000010f*t;
    c[8] += 0.218509686119999990f*t;

    // [4,4]: 0,6,
    ta = 0.282094791770000020f*a[0] + -0.180223751576000010f*a[6];
    tb = 0.282094791770000020f*b[0] + -0.180223751576000010f*b[6];
    c[4] += ta*b[4] + tb*a[4];
    t = a[4] * b[4];
    c[0] += 0.282094791770000020f*t;
    c[6] += -0.180223751576000010f*t;

    // [4,5]: 7,
    ta = 0.156078347226000000f*a[7];
    tb = 0.156078347226000000f*b[7];
    c[4] += ta*b[5] + tb*a[5];
    c[5] += ta*b[4] + tb*a[4];
    t = a[4] * b[5] + a[5] * b[4];
    c[7] += 0.156078347226000000f*t;

    // [5,5]: 0,6,8,
    ta = 0.282094791773999990f*a[0] + 0.090111875786499998f*a[6] + -0.156078347227999990f*a[8];
    tb = 0.282094791773999990f*b[0] + 0.090111875786499998f*b[6] + -0.156078347227999990f*b[8];
    c[5] += ta*b[5] + tb*a[5];
    t = a[5] * b[5];
    c[0] += 0.282094791773999990f*t;
    c[6] += 0.090111875786499998f*t;
    c[8] += -0.156078347227999990f*t;

    // [6,6]: 0,6,
    ta = 0.282094797560000000f*a[0];
    tb = 0.282094797560000000f*b[0];
    c[6] += ta*b[6] + tb*a[6];
    t = a[6] * b[6];
    c[0] += 0.282094797560000000f*t;
    c[6] += 0.180223764527000010f*t;

    // [7,7]: 0,6,8,
    ta = 0.282094791773999990f*a[0] + 0.090111875786499998f*a[6] + 0.156078347227999990f*a[8];
    tb = 0.282094791773999990f*b[0] + 0.090111875786499998f*b[6] + 0.156078347227999990f*b[8];
    c[7] += ta*b[7] + tb*a[7];
    t = a[7] * b[7];
    c[0] += 0.282094791773999990f*t;
    c[6] += 0.090111875786499998f*t;
    c[8] += 0.156078347227999990f*t;

    // [8,8]: 0,6,
    ta = 0.282094791770000020f*a[0] + -0.180223751576000010f*a[6];
    tb = 0.282094791770000020f*b[0] + -0.180223751576000010f*b[6];
    c[8] += ta*b[8] + tb*a[8];
    t = a[8] * b[8];
    c[0] += 0.282094791770000020f*t;
    c[6] += -0.180223751576000010f*t;

    // entry count=13
    // multiply count=120
    // addition count=74
    SHProduct_OUTPUT Output;
    for (int i = 0; i < NUM_COEFFS; i++) {
        Output.c[i] = c[i];
    }
    return Output;
}


//twoOffsets GetFieldOffset(float4 pos, int entityid)
float GetFieldOffset(float4 pos, int entityid)
{
    //twoOffsets FieldOffset;

    float4 relativePos = pos - aBallInfo[2 * entityid + 1];
    float ballRadius = aBallInfo[2 * entityid + 0][0];
    
    int sphereid = (length(relativePos) / ballRadius - DIST_NEAR) / (DIST_FAR - DIST_NEAR) * (SPHERENUM - 1);
    //float sphereid = (length(relativePos) / ballRadius - DIST_NEAR) / (DIST_FAR - DIST_NEAR) * (SPHERENUM - 1);
    sphereid = clamp(sphereid, 0, SPHERENUM - 1);
    //int sphereid1 = floor(sphereid);
    //int sphereid2 = ceil(sphereid);
    //FieldOffset.ratio = 0.5;
    //if (sphereid1 != sphereid2) {
    //    FieldOffset.ratio = 1.0f*sphereid2 - sphereid;
    //}

    //if (sphereid < 0)
    //    sphereid = 0;
    //else if (sphereid >= SPHERENUM)
    //    sphereid = SPHERENUM - 1;
    //return float4(1.0 * sphereid / SPHERENUM, 0, 0, 0);

    int latid = floor(acos(normalize(relativePos).y) / PI*LATNUM);
    //if (latid == 0)
    //    return float4(0, 1, 0, 0);
    //else if (latid == 1)
    //    return float4(0, 0, 1, 0);
    //else if (latid == 2)
    //    return float4(0, 1, 1, 0);
    //else
    //return float4(1.0f * (latid+1) / 6, 0, 0, 0);
    latid = clamp(latid, 0, LATNUM - 1);

    float rate = atan2(relativePos.z, relativePos.x) / 2 / PI + 0.5;
    //return float4(rate, 0, 0, 0);
    int lngid = floor(rate*LNGNUM + 0.5);
    if (lngid == LNGNUM)lngid = 0;
    //return float4(1.0f*lngid / LNGNUM, 0, 0, 0);
    lngid = clamp(lngid, 0, LNGNUM - 1);

    //int latid = 1;
    //int lngid = 2;
    //int sphereid = 1;

    return ((latid*LNGNUM + lngid)*SPHERENUM + sphereid) * 3 * NUM_COEFFS;
    //FieldOffset.offset1 = ((latid*LNGNUM + lngid)*SPHERENUM + sphereid1) * 3 * NUM_COEFFS;
    //FieldOffset.offset2 = ((latid*LNGNUM + lngid)*SPHERENUM + sphereid2) * 3 * NUM_COEFFS;
    //return FieldOffset;
    //return float4(1.0*(envOffset)/ (LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS / 4)/2+0.5f, 0, 0, 0);
}

float getMixedOOF(twoOffsets FieldOffset, int chanel, int t)
{
    float mix = 0;
    mix += getOOFBuffer(FieldOffset.offset1 + chanel * NUM_COEFFS + t)*FieldOffset.ratio;
    mix += getOOFBuffer(FieldOffset.offset2 + chanel * NUM_COEFFS + t)*(1 - FieldOffset.ratio);
    return mix ;
}
//-----------------------------------------------------------------------------
float4 GetPRTDiffuse(int iClusterOffset, float4 vPCAWeights[NUM_PCA / 4], float4 pos)
{
    //return float4(getFloat(0),getFloat(1),getFloat(3),0);
    //return tex2Dlod(OOFTexSampler, float4(0.75, 0.25, 0, 0));
    //return float4(getFloat(0),0,0,0);

    // With compressed PRT, a single diffuse channel is caluated by:
    //       R[p] = (M[k] dot L') + sum( w[p][j] * (B[k][j] dot L');
    // where the sum runs j between 0 and # of PCA vectors
    //       R[p] = exit radiance at point p
    //       M[k] = mean of cluster k 
    //       L' = source radiance coefficients
    //       w[p][j] = the j'th PCA weight for point p
    //       B[k][j] = the j'th PCA basis vector for cluster k

    float TheT[3][NUM_COEFFS];
    //float TheT[1][NUM_COEFFS];
    //float TheT[2][NUM_COEFFS];

    //float TheBR = 0, TheBG = 0, TheBB = 0;
    float4 TheB = float4(0, 0, 0, 0);
    
    for (int k = 0; k < NUM_COEFFS ; k++) {
        TheT[0][k] = aPRTClusterBases[0 * NUM_COEFFS + k];
        TheT[1][k] = aPRTClusterBases[1 * NUM_COEFFS + k];
        TheT[2][k] = aPRTClusterBases[2 * NUM_COEFFS + k];
    }

    for (int j = 0; j < (NUM_PCA / 4); j++) {
        for (int s = 0; s < 4; s++) {

            int iPCAOffset = (NUM_COEFFS * 3)*(j * 4 + s);

            for (int k = 0; k < NUM_COEFFS; k++) {
                TheT[0][k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 0 * NUM_COEFFS + k];
                TheT[1][k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 1 * NUM_COEFFS + k];
                TheT[2][k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 2 * NUM_COEFFS + k];
            }
        }
    }

    // TheT is finished. TheT is equal to BRDF.
    // Tp = TripleProduct(Op, ~rho)

    //TODO
    //rotate T p to align with global coordinate frame
    
    //compute distance from p to each scene entity
    float distance[BALLNUM];
    int ballIndex[BALLNUM];
    for (int i = 0; i < BALLNUM; i++) {
        distance[i] = length(pos - aBallInfo[2 * i + 1]);
        ballIndex[i] = i;
    }

    //sort entities in order of increasing distance
    for (int i = 0; i < BALLNUM - 1; i++) {
        for (int j = 0; j < BALLNUM - 1; j++) {
            if (distance[j]>distance[j + 1]) {
                float ft = distance[j];
                distance[j] = distance[j + 1];
                distance[j + 1] = ft;
                int it = ballIndex[j];
                ballIndex[j] = ballIndex[j + 1];
                ballIndex[j + 1] = it;              
            }
        }
    }

    //TODO
    //sort entities in order of increasing distance

    for (int i = 0; i < BALLNUM; i++) {
        int entityid = ballIndex[i];
        //if (entityid == 0)
        //    return float4(255, 0, 0, 0);
        //else if (entityid == 1)
        //    return float4(0, 255, 0, 0);

        //query SRF array to get its SRF SJ(p)
        //query OOF array to get its OOF OJ(p)
        //twoOffsets FieldOffset = GetFieldOffset(pos, entityid);
        float FieldOffset = GetFieldOffset(pos, entityid);

        //If J is a light source
        if (aBallInfo[2 * entityid + 0][1] < 2.0f) {
        
            //query SRF array to get its SRF SJ(p)
            //FieldOffset can be used here

            //TODO
            //rotate SJ(p) to align with global coordinate frame

            //Bp += DoubleProduct(SJ(p),Tp)
            for (int t = 0; t < NUM_COEFFS; t++) {
                //TheBR += aOOFBuffer[FieldOffset + 0 * NUM_COEFFS + t] * TheT[0][t];
                //TheBG += aOOFBuffer[FieldOffset + 1 * NUM_COEFFS + t] * TheT[1][t];
                //TheBB += aOOFBuffer[FieldOffset + 2 * NUM_COEFFS + t] * TheT[2][t];

                TheB[0] += getOOFBuffer(FieldOffset + 0 * NUM_COEFFS + t) * TheT[0][t];
                TheB[1] += getOOFBuffer(FieldOffset + 1 * NUM_COEFFS + t) * TheT[1][t];
                TheB[2] += getOOFBuffer(FieldOffset + 2 * NUM_COEFFS + t) * TheT[2][t];

                //TheBR += getMixedOOF(FieldOffset, 0, t) * TheT[0][t];
                //TheBG += getMixedOOF(FieldOffset, 1, t) * TheT[1][t];
                //TheBB += getMixedOOF(FieldOffset, 2, t) * TheT[2][t];
            }
        }
        //Else
        else {

            //query OOF array to get its OOF OJ(p)
            //FieldOffset can be used here

            //TODO
            //rotate OJ(p) to align with global coordinate frame

            //TODO
            //Tp = TripleProduct(OJ(p), Tp)
            
            //NUM_COEFFS must be 9 here
            float a[NUM_COEFFS], b[NUM_COEFFS]/*, c[NUM_COEFFS]*/;
            for (int colo = 0; colo < 3; colo++) {
                for (int it = 0; it < NUM_COEFFS; it++) {
                    a[it] = getOOFBuffer2(FieldOffset + colo * NUM_COEFFS + it);
                    b[it] = TheT[colo][it];
                }
                //c = SH_product_3(a, b).c;
                //for (int t = 0; t < NUM_COEFFS; t++) {
                //    TheT[colo][t] = c[t];
                //}

                float SH_TA, SH_TB, SH_T;
                // [0,0]: 0,
                SH_C[0] = 0.282094792935999980f*SH_A[0] * SH_B[0];

                // [1,1]: 0,6,8,
                SH_TA = 0.282094791773000010f*SH_A[0] + -0.126156626101000010f*SH_A[6] + -0.218509686119999990f*SH_A[8];
                SH_TB = 0.282094791773000010f*SH_B[0] + -0.126156626101000010f*SH_B[6] + -0.218509686119999990f*SH_B[8];
                SH_C[1] = SH_TA*SH_B[1] + SH_TB*SH_A[1];
                SH_T = SH_A[1] * SH_B[1];
                SH_C[0] += 0.282094791773000010f*SH_T;
                SH_C[6] = -0.126156626101000010f*SH_T;
                SH_C[8] = -0.218509686119999990f*SH_T;

                // [1,2]: 5,
                SH_TA = 0.218509686118000010f*SH_A[5];
                SH_TB = 0.218509686118000010f*SH_B[5];
                SH_C[1] += SH_TA*SH_B[2] + SH_TB*SH_A[2];
                SH_C[2] = SH_TA*SH_B[1] + SH_TB*SH_A[1];
                SH_T = SH_A[1] * SH_B[2] + SH_A[2] * SH_B[1];
                SH_C[5] = 0.218509686118000010f*SH_T;

                // [1,3]: 4,
                SH_TA = 0.218509686114999990f*SH_A[4];
                SH_TB = 0.218509686114999990f*SH_B[4];
                SH_C[1] += SH_TA*SH_B[3] + SH_TB*SH_A[3];
                SH_C[3] = SH_TA*SH_B[1] + SH_TB*SH_A[1];
                SH_T = SH_A[1] * SH_B[3] + SH_A[3] * SH_B[1];
                SH_C[4] = 0.218509686114999990f*SH_T;

                // [2,2]: 0,6,
                SH_TA = 0.282094795249000000f*SH_A[0] + 0.252313259986999990f*SH_A[6];
                SH_TB = 0.282094795249000000f*SH_B[0] + 0.252313259986999990f*SH_B[6];
                SH_C[2] += SH_TA*SH_B[2] + SH_TB*SH_A[2];
                SH_T = SH_A[2] * SH_B[2];
                SH_C[0] += 0.282094795249000000f*SH_T;
                SH_C[6] += 0.252313259986999990f*SH_T;

                // [2,3]: 7,
                SH_TA = 0.218509686118000010f*SH_A[7];
                SH_TB = 0.218509686118000010f*SH_B[7];
                SH_C[2] += SH_TA*SH_B[3] + SH_TB*SH_A[3];
                SH_C[3] += SH_TA*SH_B[2] + SH_TB*SH_A[2];
                SH_T = SH_A[2] * SH_B[3] + SH_A[3] * SH_B[2];
                SH_C[7] = 0.218509686118000010f*SH_T;

                // [3,3]: 0,6,8,
                SH_TA = 0.282094791773000010f*SH_A[0] + -0.126156626101000010f*SH_A[6] + 0.218509686119999990f*SH_A[8];
                SH_TB = 0.282094791773000010f*SH_B[0] + -0.126156626101000010f*SH_B[6] + 0.218509686119999990f*SH_B[8];
                SH_C[3] += SH_TA*SH_B[3] + SH_TB*SH_A[3];
                SH_T = SH_A[3] * SH_B[3];
                SH_C[0] += 0.282094791773000010f*SH_T;
                SH_C[6] += -0.126156626101000010f*SH_T;
                SH_C[8] += 0.218509686119999990f*SH_T;

                // [4,4]: 0,6,
                SH_TA = 0.282094791770000020f*SH_A[0] + -0.180223751576000010f*SH_A[6];
                SH_TB = 0.282094791770000020f*SH_B[0] + -0.180223751576000010f*SH_B[6];
                SH_C[4] += SH_TA*SH_B[4] + SH_TB*SH_A[4];
                SH_T = SH_A[4] * SH_B[4];
                SH_C[0] += 0.282094791770000020f*SH_T;
                SH_C[6] += -0.180223751576000010f*SH_T;

                // [4,5]: 7,
                SH_TA = 0.156078347226000000f*SH_A[7];
                SH_TB = 0.156078347226000000f*SH_B[7];
                SH_C[4] += SH_TA*SH_B[5] + SH_TB*SH_A[5];
                SH_C[5] += SH_TA*SH_B[4] + SH_TB*SH_A[4];
                SH_T = SH_A[4] * SH_B[5] + SH_A[5] * SH_B[4];
                SH_C[7] += 0.156078347226000000f*SH_T;

                // [5,5]: 0,6,8,
                SH_TA = 0.282094791773999990f*SH_A[0] + 0.090111875786499998f*SH_A[6] + -0.156078347227999990f*SH_A[8];
                SH_TB = 0.282094791773999990f*SH_B[0] + 0.090111875786499998f*SH_B[6] + -0.156078347227999990f*SH_B[8];
                SH_C[5] += SH_TA*SH_B[5] + SH_TB*SH_A[5];
                SH_T = SH_A[5] * SH_B[5];
                SH_C[0] += 0.282094791773999990f*SH_T;
                SH_C[6] += 0.090111875786499998f*SH_T;
                SH_C[8] += -0.156078347227999990f*SH_T;

                // [6,6]: 0,6,
                SH_TA = 0.282094797560000000f*SH_A[0];
                SH_TB = 0.282094797560000000f*SH_B[0];
                SH_C[6] += SH_TA*SH_B[6] + SH_TB*SH_A[6];
                SH_T = SH_A[6] * SH_B[6];
                SH_C[0] += 0.282094797560000000f*SH_T;
                SH_C[6] += 0.180223764527000010f*SH_T;

                // [7,7]: 0,6,8,
                SH_TA = 0.282094791773999990f*SH_A[0] + 0.090111875786499998f*SH_A[6] + 0.156078347227999990f*SH_A[8];
                SH_TB = 0.282094791773999990f*SH_B[0] + 0.090111875786499998f*SH_B[6] + 0.156078347227999990f*SH_B[8];
                SH_C[7] += SH_TA*SH_B[7] + SH_TB*SH_A[7];
                SH_T = SH_A[7] * SH_B[7];
                SH_C[0] += 0.282094791773999990f*SH_T;
                SH_C[6] += 0.090111875786499998f*SH_T;
                SH_C[8] += 0.156078347227999990f*SH_T;

                // [8,8]: 0,6,
                SH_TA = 0.282094791770000020f*SH_A[0] + -0.180223751576000010f*SH_A[6];
                SH_TB = 0.282094791770000020f*SH_B[0] + -0.180223751576000010f*SH_B[6];
                SH_C[8] += SH_TA*SH_B[8] + SH_TB*SH_A[8];
                SH_T = SH_A[8] * SH_B[8];
                SH_C[0] += 0.282094791770000020f*SH_T;
                SH_C[6] += -0.180223751576000010f*SH_T;


            }
/*
            // Red
            for (int it = 0; it < NUM_COEFFS; it++) {
                a[it] = getOOFBuffer2(FieldOffset + 0 * NUM_COEFFS + it);
                b[it] = TheT[0][it];
            }
            c = SH_product_3(a, b).c;
            for (int t = 0; t < NUM_COEFFS; t++) {
                TheT[0][t] = c[t];
            }
            // Green
            for (int it = 0; it < NUM_COEFFS; it++) {
                a[it] = getOOFBuffer2(FieldOffset + 1 * NUM_COEFFS + it);
                b[it] = TheT[1][it];
            }
            c = SH_product_3(a, b).c;
            for (int t = 0; t < NUM_COEFFS; t++) {
                TheT[1][t] = c[t];
            }
            // Blue
            for (int it = 0; it < NUM_COEFFS; it++) {
                a[it] = getOOFBuffer2(FieldOffset + 2 * NUM_COEFFS + it);
                b[it] = TheT[2][it];
            }
            c = SH_product_3(a, b).c;
            for (int t = 0; t < NUM_COEFFS; t++) {
                TheT[2][t] = c[t];
            }
*/
        }

        
    }

    //Bp += DoubleProduct(Sd, Tp)
    //float4 vDiffuse = float4(TheB[0], TheB[1], TheB[2], 0);
    float4 vDiffuse = TheB;
    for (int t = 0; t < NUM_COEFFS; t++) {
        vDiffuse.r += aEnvSHCoeffs[0 * NUM_COEFFS + t] * TheT[0][t];
        vDiffuse.g += aEnvSHCoeffs[1 * NUM_COEFFS + t] * TheT[1][t];
        vDiffuse.b += aEnvSHCoeffs[2 * NUM_COEFFS + t] * TheT[2][t];
    }
    return vDiffuse;
}

//float4 OldGetPRTDiffuse(int iClusterOffset, float4 vPCAWeights[NUM_PCA / 4])
//{
//    // With compressed PRT, a single diffuse channel is caluated by:
//    //       R[p] = (M[k] dot L') + sum( w[p][j] * (B[k][j] dot L');
//    // where the sum runs j between 0 and # of PCA vectors
//    //       R[p] = exit radiance at point p
//    //       M[k] = mean of cluster k 
//    //       L' = source radiance coefficients
//    //       w[p][j] = the j'th PCA weight for point p
//    //       B[k][j] = the j'th PCA basis vector for cluster k
//    //
//    // Note: since both (M[k] dot L') and (B[k][j] dot L') can be computed on the CPU, 
//    // these values are passed in as the array aPRTConstants.   
//
//    float4 vAccumR = float4(0, 0, 0, 0);
//        float4 vAccumG = float4(0, 0, 0, 0);
//        float4 vAccumB = float4(0, 0, 0, 0);
//
//        // For each channel, multiply and sum all the vPCAWeights[j] by aPRTConstants[x] 
//        // where: vPCAWeights[j] is w[p][j]
//        //		  aPRTConstants[x] is the value of (B[k][j] dot L') that was
//        //		  calculated on the CPU and passed in as a shader constant
//        // Note this code is multipled and added 4 floats at a time since each 
//        // register is a 4-D vector, and is the reason for using (NUM_PCA/4)
//    for (int j = 0; j < (NUM_PCA / 4); j++) {
//        vAccumR += vPCAWeights[j] * aPRTConstants[iClusterOffset + 1 + (NUM_PCA / 4) * 0 + j];
//        vAccumG += vPCAWeights[j] * aPRTConstants[iClusterOffset + 1 + (NUM_PCA / 4) * 1 + j];
//        vAccumB += vPCAWeights[j] * aPRTConstants[iClusterOffset + 1 + (NUM_PCA / 4) * 2 + j];
//    }
//
//    // Now for each channel, sum the 4D vector and add aPRTConstants[x] 
//    // where: aPRTConstants[x] which is the value of (M[k] dot L') and
//    //		  was calculated on the CPU and passed in as a shader constant.
//    float4 vDiffuse = aPRTConstants[iClusterOffset];
//        vDiffuse.r += dot(vAccumR, 1);
//    vDiffuse.g += dot(vAccumG, 1);
//    vDiffuse.b += dot(vAccumB, 1);
//
//    return vDiffuse;
//}

//-----------------------------------------------------------------------------
// Renders using per vertex PRT with compression with optional texture
//-----------------------------------------------------------------------------
VS_OUTPUT PRTDiffuseVS(float4 vPos : POSITION,
    float2 TexCoord : TEXCOORD0,
    int iClusterOffset : BLENDWEIGHT,
    float4 vPCAWeights[NUM_PCA / 4] : BLENDWEIGHT1,
    uniform bool bUseTexture)
{
    VS_OUTPUT Output;

    // Output the vetrex position in projection space
    Output.Position = mul(vPos, g_mWorldViewProjection);
    if (bUseTexture)
        Output.TexCoord = TexCoord;
    else
        Output.TexCoord = 0;

    // For spectral simulations the material properity is baked into the transfer coefficients.
    // If using nonspectral, then you can modulate by the diffuse material properity here.
    Output.Diffuse = GetPRTDiffuse(iClusterOffset, vPCAWeights, vPos);
    //Output.Diffuse = OldGetPRTDiffuse(0, vPCAWeights);

    Output.Diffuse *= MaterialDiffuseColor;

    return Output;
}


//-----------------------------------------------------------------------------
// Pixel shader output structure
//-----------------------------------------------------------------------------
struct PS_OUTPUT
{
    float4 RGBColor : COLOR0;  // Pixel color    
};


//-----------------------------------------------------------------------------
// Name: StandardPS
// Type: Pixel shader
// Desc: Trival pixel shader
//-----------------------------------------------------------------------------
PS_OUTPUT StandardPS(VS_OUTPUT In, uniform bool bUseTexture)
{
    PS_OUTPUT Output;

    if (bUseTexture) {
        float4 Albedo = tex2D(AlbedoSampler, In.TexCoord);
            Output.RGBColor = In.Diffuse * Albedo;
    }
    else {
        Output.RGBColor = In.Diffuse;
    }

    return Output;
}


//-----------------------------------------------------------------------------
// Renders with per vertex PRT 
//-----------------------------------------------------------------------------
technique RenderWithPRTColorLights
{
    pass P0
    {
        VertexShader = compile vs_3_0 PRTDiffuseVS(true);
        PixelShader = compile ps_2_0 StandardPS(true); // trival pixel shader 
    }
}

//-----------------------------------------------------------------------------
// Renders with per vertex PRT w/o albedo texture
//-----------------------------------------------------------------------------
technique RenderWithPRTColorLightsNoAlbedo
{
    pass P0
    {
        VertexShader = compile vs_3_0 PRTDiffuseVS(false);
        PixelShader = compile ps_2_0 StandardPS(false); // trival pixel shader 
    }
}
