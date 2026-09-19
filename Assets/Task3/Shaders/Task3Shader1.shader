Shader "Custom/Task3Shader1"
{
    Properties
    {
        [HDR] [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [HDR] _FresnelColor("Fresnel Color", Color) = (1, 1, 1, 1)
        _HeightTexture("Height Texture", 2D) = "gray" {}
        _HeightTS("Height Tiling and Offset", Vector) = (1, 1, 0, 0)
        _ColorSmoothStep("Color Smoothstep", Vector) = (1, 1, 0, 0)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
        _FresnelPow("Fresnel Power", Float) = 1.0
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
            #pragma multi_compile _ _FORWARD_PLUS

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
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
                half4 _BaseColor;
                half4 _FresnelColor;
                half2 _ColorSmoothStep;
                half _Smoothness;
                half _Metallic;
                half _Occlusion;
                half _FresnelPow;
                half _PressureRange;
                half _NoiseScale;
                half _NoiseSpeed;
                half _NoiseAmplitude;
            CBUFFER_END

            half3 Fresnel(half3 normal, half3 viewDir)
            {
                half fresnel = saturate(half(1.0) - dot(normal, viewDir));

                fresnel = pow(fresnel, _FresnelPow);

                return fresnel;
            }

            half3 CalculateAlbedo(half3 normal, half3 viewDir)
            {
                return lerp(_BaseColor, _FresnelColor, Fresnel(normal, viewDir));
            }

            half4 CalculateNoise(half2 uv)
            {
                return PerlinNoise3DWithDerivative(half3(uv * _NoiseScale, _NoiseSpeed * _Time.x)) * _NoiseAmplitude;
            }
            
            half3 CalculateColorFromLights(
                float3 viewDirWS,
                float3 normalWS,
                float3 positionWS,
                float4 positionCS,
                half3 gi,
                half3 albedo
            )
            {
                SurfaceData surfaceData;

                surfaceData.specular = half3(0.0, 0.0, 0.0);
                surfaceData.albedo = albedo;
                surfaceData.alpha = 0.0;
                surfaceData.emission = half3(0.0, 0.0, 0.0);
                surfaceData.metallic = _Metallic;
                surfaceData.normalTS = half3(0.0, 0.0, 1.0);
                surfaceData.occlusion = _Occlusion;
                surfaceData.smoothness = _Smoothness;
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
                
                half height = (texture_value - 0.5) * _PressureRange; 
                
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
                half3 gi = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);

                half3 albedo = lerp(_BaseColor, _FresnelColor, input.height);
                float3 resultColor = CalculateColorFromLights(viewDirWS, normalWS, input.positionWS, input.positionHCS, gi, albedo);

                return half4(resultColor, 1.0);
            }

            ENDHLSL
        }
    }
}
