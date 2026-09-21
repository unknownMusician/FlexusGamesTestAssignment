Shader "Custom/Task4Shader1"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SecondaryColor("Secondary Color", Color) = (1, 1, 1, 1)
        _HeightTexture("Height Texture", 2D) = "gray" {}
        _HeightTS("Height Tiling and Offset", Vector) = (1, 1, 0, 0)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
        _PressureRange("Pressure Range", Float) = 1.0
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

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/Shared/Shaders/shared.hlsl"
            #include "Assets/Shared/Shaders/noise.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float4 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
                float2 lightmapUV : TEXCOORD1;
            };

            struct VertexOutput
            {
                float4 positionHCS : SV_POSITION;
                float3 positionWS : TEXCOORD0;
                float3 normalWS: TEXCOORD1;
                float4 noiseWithDerivative: TEXCOORD2;
                float2 uv: TEXCOORD3;
                half height: TEXCOORD4;
                
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
            };

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_HeightTexture);
                SAMPLER(sampler_HeightTexture);
                half4 _HeightTS;
                half3 _BaseColor;
                half3 _SecondaryColor;
                half _Smoothness;
                half _Metallic;
                half _Occlusion;
                half _PressureRange;
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
                half2 heightUv = (output.positionWS.xz - _HeightTS.zw) / _HeightTS.xy;

                half epsilon = 0.02;
                
                half texture_value = SAMPLE_TEXTURE2D_LOD(_HeightTexture, sampler_HeightTexture, heightUv, 0).x;
                half texture_value_ex = SAMPLE_TEXTURE2D_LOD(_HeightTexture, sampler_HeightTexture, heightUv + half2(epsilon, 0), 0).x;
                half texture_value_ez = SAMPLE_TEXTURE2D_LOD(_HeightTexture, sampler_HeightTexture, heightUv + half2(0, epsilon), 0).x;

                half2 texture_value_derivative = half2(texture_value_ex - texture_value, texture_value_ez - texture_value) / epsilon;
                
                half height = texture_value * _PressureRange; 
                
                output.noiseWithDerivative = CalculateNoise(output.positionWS.xz);
                output.positionWS.y += height;
                output.positionHCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = normalize(half3(-texture_value_derivative.x, 1.0, -texture_value_derivative.y));
                output.uv = input.uv;
                output.height = height;

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS, output.vertexSH);
                
                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half3 normalWS = normalize(input.normalWS);
                half3 albedo = lerp(_BaseColor, _SecondaryColor, input.height);

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
