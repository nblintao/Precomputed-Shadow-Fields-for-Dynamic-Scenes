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
float aPRTClusterBases[((NUM_PCA + 1) * NUM_COEFFS * NUM_CHANNELS)*NUM_CLUSTERS];
float aOOFBuffer[LATNUM*LNGNUM*SPHERENUM * 3 * NUM_COEFFS];
float aEnvSHCoeffs[NUM_COEFFS * 3];
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

// NUM_COEFFS must be 9 here
//Based on http://research.microsoft.com/en-us/um/people/johnsny/#shtriple


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

    return ((latid*LNGNUM + lngid)*SPHERENUM + sphereid) * 3 * NUM_COEFFS;
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

    float BRDFR[NUM_COEFFS];
    float BRDFG[NUM_COEFFS];
    float BRDFB[NUM_COEFFS];

    float TheBR = 0, TheBG = 0, TheBB = 0;
    
    for (int k = 0; k < NUM_COEFFS ; k++) {
        BRDFR[k] = aPRTClusterBases[0 * NUM_COEFFS + k];
        BRDFG[k] = aPRTClusterBases[1 * NUM_COEFFS + k];
        BRDFB[k] = aPRTClusterBases[2 * NUM_COEFFS + k];
    }

    for (int j = 0; j < (NUM_PCA / 4); j++) {
        for (int s = 0; s < 4; s++) {

            int iPCAOffset = (NUM_COEFFS * 3)*(j * 4 + s);

            for (int k = 0; k < NUM_COEFFS; k++) {
                BRDFR[k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 0 * NUM_COEFFS + k];
                BRDFG[k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 1 * NUM_COEFFS + k];
                BRDFB[k] += vPCAWeights[j][s] * aPRTClusterBases[iPCAOffset + 2 * NUM_COEFFS + k];
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
            for (int t = 0; t < NUM_COEFFS; t++) {
                TheBR += aOOFBuffer[FieldOffset + 0 * NUM_COEFFS + t] * TheTR[t];
                TheBG += aOOFBuffer[FieldOffset + 1 * NUM_COEFFS + t] * TheTG[t];
                TheBB += aOOFBuffer[FieldOffset + 2 * NUM_COEFFS + t] * TheTB[t];
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
            //float y[NUM_COEFFS], f[NUM_COEFFS], g[NUM_COEFFS];
            //for (int it = 0; it < NUM_COEFFS; it++) {
            //    f[it] = aOOFBuffer[FieldOffset + 0 * NUM_COEFFS / 4 + it/4][it%4];
            //    g[it] = TheTR[it / 4][it % 4];
            //}
            //y = SHProduct_4(f, g);
            //for (int t = 0; t < NUM_COEFFS; t++) {
            //    TheTR[t / 4][t % 4] = y[t];
            //}
        }

        
    }

    //Bp += DoubleProduct(Sd, Tp)
    float4 vDiffuse = float4(TheBR, TheBG, TheBB, 0);
    for (int t = 0; t < NUM_COEFFS; t++) {
        vDiffuse.r += aEnvSHCoeffs[0 * NUM_COEFFS + t] * TheTR[t];
        vDiffuse.g += aEnvSHCoeffs[1 * NUM_COEFFS + t] * TheTG[t];
        vDiffuse.b += aEnvSHCoeffs[2 * NUM_COEFFS + t] * TheTB[t];
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
