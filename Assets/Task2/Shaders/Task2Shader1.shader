Shader "Custom/Task2Shader1"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SecondaryColor("Secondary Color", Color) = (1, 1, 1, 1)
        _ColorSmoothStep("Color Smoothstep", Vector) = (1, 1, 0, 0)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
        _NoiseScale("Noise Scale", Float) = 1.0
        _NoiseSpeed("Noise Speed", Float) = 1.0
        _NoiseAmplitude("Noise Amplitude", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local_fragment _ENVIRONMENTREFLECTIONS_OFF

            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
            #pragma multi_compile _ _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile _ _FORWARD_PLUS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Shared/Shaders/shared.hlsl"
            #include "Assets/Shared/Shaders/noise.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 normalOS : NORMAL;
                float2 lightmapUV : TEXCOORD1;
            };

            struct VertexOutput
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS: TEXCOORD1;
                float4 noiseWithDerivative: TEXCOORD2;
                
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SecondaryColor;
                half2 _ColorSmoothStep;
                half _Smoothness;
                half _Metallic;
                half _Occlusion;
                half _NoiseScale;
                half _NoiseSpeed;
                half _NoiseAmplitude;
            CBUFFER_END

            half4 CalculateNoise(half2 uv)
            {
                return PerlinNoise3DWithDerivative(half3(uv * _NoiseScale, _NoiseSpeed * _Time.x)) * _NoiseAmplitude;
            }

            VertexOutput vert(Attributes input)
            {
                VertexOutput output;

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.noiseWithDerivative = CalculateNoise(output.positionWS.xz);
                output.positionWS.y += output.noiseWithDerivative.w;
                output.positionHCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = normalize(half3(-output.noiseWithDerivative.x, 1.0, -output.noiseWithDerivative.z));

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS, output.vertexSH);
                
                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half3 normalWS = normalize(input.normalWS);
                half3 albedo = lerp(_BaseColor, _SecondaryColor, smoothstep(_ColorSmoothStep.x - _ColorSmoothStep.y * 0.5, _ColorSmoothStep.x + _ColorSmoothStep.y * 0.5, input.noiseWithDerivative.w));

                float3 resultColor = FlexusTestCalculateLightingRealistic(
                    viewDirWS,
                    normalWS,
                    input.positionWS,
                    input.positionHCS,
                    albedo,
                    _Metallic,
                    _Occlusion,
                    _Smoothness,
                    SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS)
                );

                return half4(resultColor, 1.0);
            }

            ENDHLSL
        }
    }
}
