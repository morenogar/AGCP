//***************************************************************************************
// Default.hlsl by Frank Luna (C) 2015 All Rights Reserved.
//
// Default shader, currently supports lighting.
//***************************************************************************************

// Defaults for number of lights.
#ifndef NUM_DIR_LIGHTS
#define NUM_DIR_LIGHTS 1
#endif

#ifndef NUM_POINT_LIGHTS
#define NUM_POINT_LIGHTS 0
#endif

#ifndef NUM_SPOT_LIGHTS
#define NUM_SPOT_LIGHTS 5
#endif

// Include structures and functions for lighting.
#include "LightingUtil.hlsl"

// Constant data that varies per frame.

cbuffer cbPerObject : register(b0)
{
  float4x4 gWorld;
};

cbuffer cbMaterial : register(b1)
{
  float4 gDiffuseAlbedo;
  float3 gFresnelR0;
  float  gRoughness;
  float4x4 gMatTransform;
};

// Constant data that varies per material.
cbuffer cbPass : register(b2)
{
  float4x4 gView;
  float4x4 gInvView;
  float4x4 gProj;
  float4x4 gInvProj;
  float4x4 gViewProj;
  float4x4 gInvViewProj;
  float3 gEyePosW;
  float cbPerObjectPad1;
  float2 gRenderTargetSize;
  float2 gInvRenderTargetSize;
  float gNearZ;
  float gFarZ;
  float gTotalTime;
  float gDeltaTime;
  float4 gAmbientLight;

  // Indices [0, NUM_DIR_LIGHTS) are directional lights;
  // indices [NUM_DIR_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHTS) are point lights;
  // indices [NUM_DIR_LIGHTS+NUM_POINT_LIGHTS, NUM_DIR_LIGHTS+NUM_POINT_LIGHT+NUM_SPOT_LIGHTS)
  // are spot lights for a maximum of MaxLights per object.
  Light gLights[MaxLights];
};

struct VertexIn
{
  float3 PosL    : POSITION;
  float3 NormalL : NORMAL;
};

struct VertexOut
{
  float4 PosH    : SV_POSITION;
  float3 PosW    : POSITION;
  float3 NormalW : NORMAL;
  float4 Color : COLOR;
  float4 Color2 : COLOR2;
  float3 lightVec : LIGHTVEC;
};

VertexOut VS(VertexIn vin)
{
  VertexOut vout = (VertexOut)0.0f;

  // Transform to world space.
  float4 posW = mul(float4(vin.PosL, 1.0f), gWorld);
  vout.PosW = posW.xyz;

  // Assumes nonuniform scaling; otherwise, need to use inverse-transpose of world matrix.
  vout.NormalW = mul(vin.NormalL, (float3x3)gWorld);

  // Transform to homogeneous clip space.
  vout.PosH = mul(posW, gViewProj);

  // vout.Timer = timer;

  float4 test_color = gAmbientLight;
  test_color.x *= cos(gTotalTime * 0.5) * -1;
  vout.Color = test_color;


  float4 test_color_2 = gDiffuseAlbedo;
  test_color_2.y *= cos(gTotalTime * 0.5) * -1;
  vout.Color2 = test_color_2;


  vout.lightVec = -gLights[0].Direction;

  return vout;
}

float4 PS(VertexOut pin) : SV_Target
{
  // Interpolating normal can unnormalize it, so renormalize it.
  pin.NormalW = normalize(pin.NormalW);

// Vector from point being lit to eye. 
float3 toEyeW = normalize(gEyePosW - pin.PosW);

float4 test_gAmbientLight = pin.Color;

float4 test_gDiffuseAlbedo = pin.Color2;

// Indirect lighting.
  float4 ambient = test_gAmbientLight * test_gDiffuseAlbedo;

  //  gAmbientLight = test_gAmbientLight;

    const float shininess = 1.0f - gRoughness;
    Material mat = { gDiffuseAlbedo, gFresnelR0, shininess };
    float3 shadowFactor = 1.0f;
    float4 directLight = ComputeLighting(gLights, mat, pin.PosW,
        pin.NormalW, toEyeW, shadowFactor);

    float4 litColor = ambient + directLight;

    // Common convention to take alpha from diffuse material.
    litColor.a = gDiffuseAlbedo.a;


    float4 toon_color = litColor;

    float toon_intensity = dot(pin.lightVec, pin.NormalW);

    if (toon_intensity > 0.95)
      toon_color *= 0.95;
    else if (toon_intensity > 0.5)
      toon_color *= 0.5;
    else if (toon_intensity > 0.25)
      toon_color *= 0.25;
    else
      toon_color *= 0.1;


    return toon_color;
}


