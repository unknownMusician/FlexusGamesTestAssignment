Shader "Custom/Task2Shader2"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SecondaryColor("Secondary Color", Color) = (1, 1, 1, 1)
        _ColorSmoothStep("Color Smoothstep", Vector) = (1, 1, 0, 0)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
        _HeightNoiseScale("Height Noise Scale", Float) = 1.0
        _HeightNoiseSpeed("Height Noise Speed", Float) = 1.0
        _HeightNoiseAmplitude("Height Noise Amplitude", Float) = 1.0
        _SkewNoiseScale("Skew Noise Scale", Float) = 1.0
        _SkewNoiseSpeed("Skew Noise Speed", Float) = 1.0
        _SkewNoiseAmplitude("Skew Noise Amplitude", Float) = 1.0
        _SkewNoiseAnisotropy("Skew Noise Anisotropy", Float) = 1.0
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
                float noise: TEXCOORD2;
                
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 3);
            };

            CBUFFER_START(UnityPerMaterial)
                half4 _BaseColor;
                half4 _SecondaryColor;
                half2 _ColorSmoothStep;
                half _Smoothness;
                half _Metallic;
                half _Occlusion;
                half _HeightNoiseScale;
                half _HeightNoiseSpeed;
                half _HeightNoiseAmplitude;
                half _SkewNoiseScale;
                half _SkewNoiseSpeed;
                half _SkewNoiseAmplitude;
                half _SkewNoiseAnisotropy;
            CBUFFER_END

            half CalculateNoise(half2 uv)
            {
                half3 perlinInput = half3(uv * _SkewNoiseScale, _SkewNoiseSpeed * _Time.x);
                half2 skew = half2(
                    PerlinNoise3D(perlinInput) * _SkewNoiseAmplitude,
                    PerlinNoise3D(perlinInput + half3(0, _SkewNoiseAnisotropy, 0)) * _SkewNoiseAmplitude
                );

                skew = skew * 2 - 1;
                

                return PerlinNoise3D(half3((uv + skew) * _HeightNoiseScale, _HeightNoiseSpeed * _Time.x)) * _HeightNoiseAmplitude;
            }

            half3 CalculateNoiseWithDerivative(half2 uv, half epsilon)
            {
                half noise = CalculateNoise(uv);
                half noise_ex = CalculateNoise(uv + half2(epsilon, 0));
                half noise_ez = CalculateNoise(uv + half2(0, epsilon));
                
                half2 noise_derivative = half2(noise_ex - noise, noise_ez - noise) / epsilon;

                return half3(noise_derivative, noise);
            }

            VertexOutput vert(Attributes input)
            {
                VertexOutput output;

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                half3 noiseWithDerivative = CalculateNoiseWithDerivative(output.positionWS.xz, 0.1);

                output.noise = noiseWithDerivative.z;
                output.positionWS.y += output.noise;
                output.positionHCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = normalize(half3(-noiseWithDerivative.x, 1.0, -noiseWithDerivative.y));

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS, output.vertexSH);
                
                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                half3 noiseWithDerivative = CalculateNoiseWithDerivative(input.positionWS.xz, 0.2);
                
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                float3 normalWS = normalize(float3(-noiseWithDerivative.x, 1.0, -noiseWithDerivative.y));
                half3 albedo = lerp(_BaseColor, _SecondaryColor, smoothstep(_ColorSmoothStep.x - _ColorSmoothStep.y * 0.5, _ColorSmoothStep.x + _ColorSmoothStep.y * 0.5, input.noise));

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
