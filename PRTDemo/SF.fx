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

#define NUM_CHANNELS	3

#define BALLNUM 2
#define SPHERENUM 8
#define LATNUM 5
#define LNGNUM 5

// The values for NUM_CLUSTERS, NUM_PCA and NUM_COEFFS are
// defined by the app upon the D3DXCreateEffectFromFile() call.

//float4 aPRTConstants[NUM_CLUSTERS*(1 + NUM_CHANNELS*(NUM_PCA / 4))];
float4 aPRTClusterBases[((NUM_PCA + 1) * NUM_COEFFS / 4 * NUM_CHANNELS)*NUM_CLUSTERS];

float4 aOOFBuffer[LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS/4];
float4 aEnvSHCoeffs[NUM_COEFFS / 4 * 3];
float4 aBallInfo[2*BALLNUM];

float4 MaterialDiffuseColor = { 1.0f, 1.0f, 1.0f, 1.0f };

#define PI 3.14159265359f
#define TheTR BRDFR
#define TheTG BRDFG
#define TheTB BRDFB

//-----------------------------------------------------------------------------
sampler AlbedoSampler = sampler_state
{
    Texture = (AlbedoTexture);
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
    float y[NUM_COEFFS];
};

// NUM_COEFFS must be 16 here
SHProduct_OUTPUT SHProduct_4(float f[NUM_COEFFS], float g[NUM_COEFFS])
{
    float y[NUM_COEFFS] = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0};
    float tf, tg, t;
    //Based on http://research.microsoft.com/en-us/um/people/johnsny/#shtriple
    // [0,0]: 0,
    y[0] = 0.282094792935999980f*f[0] * g[0];

    // [1,1]: 0,6,8,
    tf = 0.282094791773000010f*f[0] - 0.126156626101000010f*f[6] - 0.218509686119999990f*f[8];
    tg = 0.282094791773000010f*g[0] - 0.126156626101000010f*g[6] - 0.218509686119999990f*g[8];
    y[1] = tf*g[1] + tg*f[1];
    t = f[1] * g[1];
    y[0] += 0.282094791773000010f*t;
    y[6] = -0.126156626101000010f*t;
    y[8] = -0.218509686119999990f*t;

    // [1,4]: 3,13,15,
    tf = 0.218509686114999990f*f[3] - 0.058399170082300000f*f[13] - 0.226179013157999990f*f[15];
    tg = 0.218509686114999990f*g[3] - 0.058399170082300000f*g[13] - 0.226179013157999990f*g[15];
    y[1] += tf*g[4] + tg*f[4];
    y[4] = tf*g[1] + tg*f[1];
    t = f[1] * g[4] + f[4] * g[1];
    y[3] = 0.218509686114999990f*t;
    y[13] = -0.058399170082300000f*t;
    y[15] = -0.226179013157999990f*t;

    // [1,5]: 2,12,14,
    tf = 0.218509686118000010f*f[2] - 0.143048168103000000f*f[12] - 0.184674390923000000f*f[14];
    tg = 0.218509686118000010f*g[2] - 0.143048168103000000f*g[12] - 0.184674390923000000f*g[14];
    y[1] += tf*g[5] + tg*f[5];
    y[5] = tf*g[1] + tg*f[1];
    t = f[1] * g[5] + f[5] * g[1];
    y[2] = 0.218509686118000010f*t;
    y[12] = -0.143048168103000000f*t;
    y[14] = -0.184674390923000000f*t;

    // [1,6]: 11,
    tf = 0.202300659402999990f*f[11];
    tg = 0.202300659402999990f*g[11];
    y[1] += tf*g[6] + tg*f[6];
    y[6] += tf*g[1] + tg*f[1];
    t = f[1] * g[6] + f[6] * g[1];
    y[11] = 0.202300659402999990f*t;

    // [1,8]: 9,11,
    tf = 0.226179013155000000f*f[9] + 0.058399170081799998f*f[11];
    tg = 0.226179013155000000f*g[9] + 0.058399170081799998f*g[11];
    y[1] += tf*g[8] + tg*f[8];
    y[8] += tf*g[1] + tg*f[1];
    t = f[1] * g[8] + f[8] * g[1];
    y[9] = 0.226179013155000000f*t;
    y[11] += 0.058399170081799998f*t;

    // [2,2]: 0,6,
    tf = 0.282094795249000000f*f[0] + 0.252313259986999990f*f[6];
    tg = 0.282094795249000000f*g[0] + 0.252313259986999990f*g[6];
    y[2] += tf*g[2] + tg*f[2];
    t = f[2] * g[2];
    y[0] += 0.282094795249000000f*t;
    y[6] += 0.252313259986999990f*t;

    // [2,6]: 12,
    tf = 0.247766706973999990f*f[12];
    tg = 0.247766706973999990f*g[12];
    y[2] += tf*g[6] + tg*f[6];
    y[6] += tf*g[2] + tg*f[2];
    t = f[2] * g[6] + f[6] * g[2];
    y[12] += 0.247766706973999990f*t;

    // [3,3]: 0,6,8,
    tf = 0.282094791773000010f*f[0] - 0.126156626101000010f*f[6] + 0.218509686119999990f*f[8];
    tg = 0.282094791773000010f*g[0] - 0.126156626101000010f*g[6] + 0.218509686119999990f*g[8];
    y[3] += tf*g[3] + tg*f[3];
    t = f[3] * g[3];
    y[0] += 0.282094791773000010f*t;
    y[6] += -0.126156626101000010f*t;
    y[8] += 0.218509686119999990f*t;

    // [3,6]: 13,
    tf = 0.202300659402999990f*f[13];
    tg = 0.202300659402999990f*g[13];
    y[3] += tf*g[6] + tg*f[6];
    y[6] += tf*g[3] + tg*f[3];
    t = f[3] * g[6] + f[6] * g[3];
    y[13] += 0.202300659402999990f*t;

    // [3,7]: 2,12,14,
    tf = 0.218509686118000010f*f[2] - 0.143048168103000000f*f[12] + 0.184674390923000000f*f[14];
    tg = 0.218509686118000010f*g[2] - 0.143048168103000000f*g[12] + 0.184674390923000000f*g[14];
    y[3] += tf*g[7] + tg*f[7];
    y[7] = tf*g[3] + tg*f[3];
    t = f[3] * g[7] + f[7] * g[3];
    y[2] += 0.218509686118000010f*t;
    y[12] += -0.143048168103000000f*t;
    y[14] += 0.184674390923000000f*t;

    // [3,8]: 13,15,
    tf = -0.058399170081799998f*f[13] + 0.226179013155000000f*f[15];
    tg = -0.058399170081799998f*g[13] + 0.226179013155000000f*g[15];
    y[3] += tf*g[8] + tg*f[8];
    y[8] += tf*g[3] + tg*f[3];
    t = f[3] * g[8] + f[8] * g[3];
    y[13] += -0.058399170081799998f*t;
    y[15] += 0.226179013155000000f*t;

    // [4,4]: 0,6,
    tf = 0.282094791770000020f*f[0] - 0.180223751576000010f*f[6];
    tg = 0.282094791770000020f*g[0] - 0.180223751576000010f*g[6];
    y[4] += tf*g[4] + tg*f[4];
    t = f[4] * g[4];
    y[0] += 0.282094791770000020f*t;
    y[6] += -0.180223751576000010f*t;

    // [4,5]: 7,
    tf = 0.156078347226000000f*f[7];
    tg = 0.156078347226000000f*g[7];
    y[4] += tf*g[5] + tg*f[5];
    y[5] += tf*g[4] + tg*f[4];
    t = f[4] * g[5] + f[5] * g[4];
    y[7] += 0.156078347226000000f*t;

    // [4,9]: 3,13,
    tf = 0.226179013157999990f*f[3] - 0.094031597258400004f*f[13];
    tg = 0.226179013157999990f*g[3] - 0.094031597258400004f*g[13];
    y[4] += tf*g[9] + tg*f[9];
    y[9] += tf*g[4] + tg*f[4];
    t = f[4] * g[9] + f[9] * g[4];
    y[3] += 0.226179013157999990f*t;
    y[13] += -0.094031597258400004f*t;

    // [4,10]: 2,12,
    tf = 0.184674390919999990f*f[2] - 0.188063194517999990f*f[12];
    tg = 0.184674390919999990f*g[2] - 0.188063194517999990f*g[12];
    y[4] += tf*g[10] + tg*f[10];
    y[10] = tf*g[4] + tg*f[4];
    t = f[4] * g[10] + f[10] * g[4];
    y[2] += 0.184674390919999990f*t;
    y[12] += -0.188063194517999990f*t;

    // [4,11]: 3,13,15,
    tf = -0.058399170082300000f*f[3] + 0.145673124078000010f*f[13] + 0.094031597258400004f*f[15];
    tg = -0.058399170082300000f*g[3] + 0.145673124078000010f*g[13] + 0.094031597258400004f*g[15];
    y[4] += tf*g[11] + tg*f[11];
    y[11] += tf*g[4] + tg*f[4];
    t = f[4] * g[11] + f[11] * g[4];
    y[3] += -0.058399170082300000f*t;
    y[13] += 0.145673124078000010f*t;
    y[15] += 0.094031597258400004f*t;

    // [5,5]: 0,6,8,
    tf = 0.282094791773999990f*f[0] + 0.090111875786499998f*f[6] - 0.156078347227999990f*f[8];
    tg = 0.282094791773999990f*g[0] + 0.090111875786499998f*g[6] - 0.156078347227999990f*g[8];
    y[5] += tf*g[5] + tg*f[5];
    t = f[5] * g[5];
    y[0] += 0.282094791773999990f*t;
    y[6] += 0.090111875786499998f*t;
    y[8] += -0.156078347227999990f*t;

    // [5,9]: 14,
    tf = 0.148677009677999990f*f[14];
    tg = 0.148677009677999990f*g[14];
    y[5] += tf*g[9] + tg*f[9];
    y[9] += tf*g[5] + tg*f[5];
    t = f[5] * g[9] + f[9] * g[5];
    y[14] += 0.148677009677999990f*t;

    // [5,10]: 3,13,15,
    tf = 0.184674390919999990f*f[3] + 0.115164716490000000f*f[13] - 0.148677009678999990f*f[15];
    tg = 0.184674390919999990f*g[3] + 0.115164716490000000f*g[13] - 0.148677009678999990f*g[15];
    y[5] += tf*g[10] + tg*f[10];
    y[10] += tf*g[5] + tg*f[5];
    t = f[5] * g[10] + f[10] * g[5];
    y[3] += 0.184674390919999990f*t;
    y[13] += 0.115164716490000000f*t;
    y[15] += -0.148677009678999990f*t;

    // [5,11]: 2,12,14,
    tf = 0.233596680327000010f*f[2] + 0.059470803871800003f*f[12] - 0.115164716491000000f*f[14];
    tg = 0.233596680327000010f*g[2] + 0.059470803871800003f*g[12] - 0.115164716491000000f*g[14];
    y[5] += tf*g[11] + tg*f[11];
    y[11] += tf*g[5] + tg*f[5];
    t = f[5] * g[11] + f[11] * g[5];
    y[2] += 0.233596680327000010f*t;
    y[12] += 0.059470803871800003f*t;
    y[14] += -0.115164716491000000f*t;

    // [6,6]: 0,6,
    tf = 0.282094797560000000f*f[0];
    tg = 0.282094797560000000f*g[0];
    y[6] += tf*g[6] + tg*f[6];
    t = f[6] * g[6];
    y[0] += 0.282094797560000000f*t;
    y[6] += 0.180223764527000010f*t;

    // [7,7]: 0,6,8,
    tf = 0.282094791773999990f*f[0] + 0.090111875786499998f*f[6] + 0.156078347227999990f*f[8];
    tg = 0.282094791773999990f*g[0] + 0.090111875786499998f*g[6] + 0.156078347227999990f*g[8];
    y[7] += tf*g[7] + tg*f[7];
    t = f[7] * g[7];
    y[0] += 0.282094791773999990f*t;
    y[6] += 0.090111875786499998f*t;
    y[8] += 0.156078347227999990f*t;

    // [7,10]: 1,9,11,
    tf = 0.184674390919999990f*f[1] + 0.148677009678999990f*f[9] + 0.115164716490000000f*f[11];
    tg = 0.184674390919999990f*g[1] + 0.148677009678999990f*g[9] + 0.115164716490000000f*g[11];
    //y[7] += tf*g[10] + tg*f[10];
    //y[10] += tf*g[7] + tg*f[7];
    //t = f[7] * g[10] + f[10] * g[7];
    //y[1] += 0.184674390919999990f*t;
    //y[9] += 0.148677009678999990f*t;
    //y[11] += 0.115164716490000000f*t;

    //// [7,13]: 2,12,14,
    //tf = 0.233596680327000010f*f[2] + 0.059470803871800003f*f[12] + 0.115164716491000000f*f[14];
    //tg = 0.233596680327000010f*g[2] + 0.059470803871800003f*g[12] + 0.115164716491000000f*g[14];
    //y[7] += tf*g[13] + tg*f[13];
    //y[13] += tf*g[7] + tg*f[7];
    //t = f[7] * g[13] + f[13] * g[7];
    //y[2] += 0.233596680327000010f*t;
    //y[12] += 0.059470803871800003f*t;
    //y[14] += 0.115164716491000000f*t;

    //// [7,14]: 15,
    //tf = 0.148677009677999990f*f[15];
    //tg = 0.148677009677999990f*g[15];
    //y[7] += tf*g[14] + tg*f[14];
    //y[14] += tf*g[7] + tg*f[7];
    //t = f[7] * g[14] + f[14] * g[7];
    //y[15] += 0.148677009677999990f*t;

    //// [8,8]: 0,6,
    //tf = 0.282094791770000020f*f[0] - 0.180223751576000010f*f[6];
    //tg = 0.282094791770000020f*g[0] - 0.180223751576000010f*g[6];
    //y[8] += tf*g[8] + tg*f[8];
    //t = f[8] * g[8];
    //y[0] += 0.282094791770000020f*t;
    //y[6] += -0.180223751576000010f*t;

    //// [8,9]: 11,
    //tf = -0.094031597259499999f*f[11];
    //tg = -0.094031597259499999f*g[11];
    //y[8] += tf*g[9] + tg*f[9];
    //y[9] += tf*g[8] + tg*f[8];
    //t = f[8] * g[9] + f[9] * g[8];
    //y[11] += -0.094031597259499999f*t;

    //// [8,13]: 15,
    //tf = -0.094031597259499999f*f[15];
    //tg = -0.094031597259499999f*g[15];
    //y[8] += tf*g[13] + tg*f[13];
    //y[13] += tf*g[8] + tg*f[8];
    //t = f[8] * g[13] + f[13] * g[8];
    //y[15] += -0.094031597259499999f*t;

    //// [8,14]: 2,12,
    //tf = 0.184674390919999990f*f[2] - 0.188063194517999990f*f[12];
    //tg = 0.184674390919999990f*g[2] - 0.188063194517999990f*g[12];
    //y[8] += tf*g[14] + tg*f[14];
    //y[14] += tf*g[8] + tg*f[8];
    //t = f[8] * g[14] + f[14] * g[8];
    //y[2] += 0.184674390919999990f*t;
    //y[12] += -0.188063194517999990f*t;

    //// [9,9]: 0,6,
    //tf = 0.282094791766999970f*f[0] - 0.210261043508000010f*f[6];
    //tg = 0.282094791766999970f*g[0] - 0.210261043508000010f*g[6];
    //y[9] += tf*g[9] + tg*f[9];
    //t = f[9] * g[9];
    //y[0] += 0.282094791766999970f*t;
    //y[6] += -0.210261043508000010f*t;

    //// [10,10]: 0,6,
    //tf = 0.282094791771999980f*f[0] + 0.000000000000012458f*f[6];
    //tg = 0.282094791771999980f*g[0] + 0.000000000000012458f*g[6];
    //y[10] += tf*g[10] + tg*f[10];
    //t = f[10] * g[10];
    //y[0] += 0.282094791771999980f*t;
    //y[6] += 0.000000000000012458f*t;

    //// [11,11]: 0,6,8,
    //tf = 0.282094791773999990f*f[0] + 0.126156626101000010f*f[6] - 0.145673124078999990f*f[8];
    //tg = 0.282094791773999990f*g[0] + 0.126156626101000010f*g[6] - 0.145673124078999990f*g[8];
    //y[11] += tf*g[11] + tg*f[11];
    //t = f[11] * g[11];
    //y[0] += 0.282094791773999990f*t;
    //y[6] += 0.126156626101000010f*t;
    //y[8] += -0.145673124078999990f*t;

    //// [12,12]: 0,6,
    //tf = 0.282094799871999980f*f[0] + 0.168208852954000010f*f[6];
    //tg = 0.282094799871999980f*g[0] + 0.168208852954000010f*g[6];
    //y[12] += tf*g[12] + tg*f[12];
    //t = f[12] * g[12];
    //y[0] += 0.282094799871999980f*t;
    //y[6] += 0.168208852954000010f*t;

    //// [13,13]: 0,6,8,
    //tf = 0.282094791773999990f*f[0] + 0.126156626101000010f*f[6] + 0.145673124078999990f*f[8];
    //tg = 0.282094791773999990f*g[0] + 0.126156626101000010f*g[6] + 0.145673124078999990f*g[8];
    //y[13] += tf*g[13] + tg*f[13];
    //t = f[13] * g[13];
    //y[0] += 0.282094791773999990f*t;
    //y[6] += 0.126156626101000010f*t;
    //y[8] += 0.145673124078999990f*t;

    //// [14,14]: 0,6,
    //tf = 0.282094791771999980f*f[0] + 0.000000000000012495f*f[6];
    //tg = 0.282094791771999980f*g[0] + 0.000000000000012495f*g[6];
    //y[14] += tf*g[14] + tg*f[14];
    //t = f[14] * g[14];
    //y[0] += 0.282094791771999980f*t;
    //y[6] += 0.000000000000012495f*t;

    //// [15,15]: 0,6,
    //tf = 0.282094791766999970f*f[0] - 0.210261043508000010f*f[6];
    //tg = 0.282094791766999970f*g[0] - 0.210261043508000010f*g[6];
    //y[15] += tf*g[15] + tg*f[15];
    //t = f[15] * g[15];
    //y[0] += 0.282094791766999970f*t;
    //y[6] += -0.210261043508000010f*t;
//
//    // multiply count=405
    SHProduct_OUTPUT Output;
    for (int i = 0; i < NUM_COEFFS; i++) {
        Output.y[i] = y[i];
    }
    return Output;
}


float GetFieldOffset(float4 pos, int entityid)
{
    float4 relativePos = pos - aBallInfo[2 * entityid + 1];
    float ballRadius = aBallInfo[2 * entityid + 0][0];

    int sphereid = (length(relativePos) / ballRadius - 0.2) / ((8.0f - 0.2f) / (SPHERENUM - 1));
    sphereid = clamp(sphereid, 0, SPHERENUM - 1);
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

    return ((latid*LNGNUM + lngid)*SPHERENUM + sphereid) * 3 * NUM_COEFFS / 4;
    //return float4(1.0*(envOffset)/ (LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS / 4)/2+0.5f, 0, 0, 0);
}


//-----------------------------------------------------------------------------
float4 GetPRTDiffuse(int iClusterOffset, float4 vPCAWeights[NUM_PCA / 4], float4 pos)
{
    // With compressed PRT, a single diffuse channel is caluated by:
    //       R[p] = (M[k] dot L') + sum( w[p][j] * (B[k][j] dot L');
    // where the sum runs j between 0 and # of PCA vectors
    //       R[p] = exit radiance at point p
    //       M[k] = mean of cluster k 
    //       L' = source radiance coefficients
    //       w[p][j] = the j'th PCA weight for point p
    //       B[k][j] = the j'th PCA basis vector for cluster k

    float4 BRDFR[NUM_COEFFS / 4];
    float4 BRDFG[NUM_COEFFS / 4];
    float4 BRDFB[NUM_COEFFS / 4];

    float TheBR = 0, TheBG = 0, TheBB = 0;
    
    for (int k = 0; k < (NUM_COEFFS / 4); k++) {
        BRDFR[k] = aPRTClusterBases[0 * (NUM_COEFFS / 4) + k];
        BRDFG[k] = aPRTClusterBases[1 * (NUM_COEFFS / 4) + k];
        BRDFB[k] = aPRTClusterBases[2 * (NUM_COEFFS / 4) + k];
    }

    for (int j = 0; j < (NUM_PCA / 4); j++) {
        for (int s = 0; s < 4; s++) {

            int iPCAOffset = (NUM_COEFFS / 4 * 3)*(j * 4 + s);

            for (int k = 0; k < (NUM_COEFFS / 4); k++) {
                BRDFR[k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 0 * (NUM_COEFFS / 4) + k];
                BRDFG[k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 1 * (NUM_COEFFS / 4) + k];
                BRDFB[k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 2 * (NUM_COEFFS / 4) + k];
            }
        }
    }

    // BRDF is finished. TheT is equal to BRDF.
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
        float FieldOffset = GetFieldOffset(pos, entityid);

        //If J is a light source
        if (aBallInfo[2 * entityid + 0][1] < 2.0f) {
        
            //query SRF array to get its SRF SJ(p)
            //FieldOffset can be used here

            //TODO
            //rotate SJ(p) to align with global coordinate frame

            //Bp += DoubleProduct(SJ(p),Tp)
            for (int t = 0; t < (NUM_COEFFS / 4); t++) {
                TheBR += dot(aOOFBuffer[FieldOffset + 0 * NUM_COEFFS / 4 + t], TheTR[t]);
                TheBG += dot(aOOFBuffer[FieldOffset + 1 * NUM_COEFFS / 4 + t], TheTG[t]);
                TheBB += dot(aOOFBuffer[FieldOffset + 2 * NUM_COEFFS / 4 + t], TheTB[t]);
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
            
            //NUM_COEFFS must be 16 here
            float y[NUM_COEFFS], f[NUM_COEFFS], g[NUM_COEFFS];
            for (int it = 0; it < NUM_COEFFS; it++) {
                f[it] = aOOFBuffer[FieldOffset + 0 * NUM_COEFFS / 4 + it/4][it%4];
                g[it] = TheTR[it / 4][it % 4];
            }
            y = SHProduct_4(f, g);
            for (int t = 0; t < NUM_COEFFS; t++) {
                TheTR[t / 4][t % 4] = y[t];
            }
        }

        
    }

    //Bp += DoubleProduct(Sd, Tp)
    float4 vDiffuse = float4(TheBR, TheBG, TheBB, 0);
    for (int t = 0; t < (NUM_COEFFS / 4); t++) {
        vDiffuse.r += dot(aEnvSHCoeffs[0 * NUM_COEFFS / 4 + t], TheTR[t]);
        vDiffuse.g += dot(aEnvSHCoeffs[1 * NUM_COEFFS / 4 + t], TheTG[t]);
        vDiffuse.b += dot(aEnvSHCoeffs[2 * NUM_COEFFS / 4 + t], TheTB[t]);
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
