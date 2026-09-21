#ifndef FLEXUS_TEST_SHARED_INCLUDED
#define FLEXUS_TEST_SHARED_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

half FlexusTestFresnel(half3 normal, half3 viewDir)
{
    return saturate(half(1.0) - dot(normal, viewDir));
}

half3 FlexusTestCalculateLightingRealistic(
    float3 viewDirWS,
    float3 normalWS,
    float3 positionWS,
    float4 positionCS,
    half3 albedo,
    half metallic,
    half occlusion,
    half smoothness,
    half3 gi
)
{
    SurfaceData surfaceData;

    surfaceData.specular = half3(0.0, 0.0, 0.0);
    surfaceData.albedo = albedo;
    surfaceData.alpha = 0.0;
    surfaceData.emission = half3(0.0, 0.0, 0.0);
    surfaceData.metallic = metallic;
    surfaceData.normalTS = half3(0.0, 0.0, 1.0);
    surfaceData.occlusion = occlusion;
    surfaceData.smoothness = smoothness;
    surfaceData.clearCoatMask = 0.0;
    surfaceData.clearCoatSmoothness = 1.0;

    InputData inputData = (InputData)0;

    inputData.positionWS = positionWS;
    inputData.normalWS = normalWS;
    inputData.viewDirectionWS = viewDirWS;
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(positionCS);
    inputData.bakedGI = gi;
    inputData.shadowCoord = TransformWorldToShadowCoord(positionWS);
                
    half4 pbr = UniversalFragmentPBR(inputData, surfaceData);
                
    return pbr.xyz;
}

#endif