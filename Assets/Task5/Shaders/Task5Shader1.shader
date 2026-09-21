Shader "Custom/Task5Shader1"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _HueCenter("Hue Center", Float) = 0
        _HueDepth("Hue Depth", Float) = 1
        _BottomColor("Bottom Color", Color) = (1, 1, 1, 1)
        _TopColor("Top Color", Color) = (1, 1, 1, 1)
        _IdleColor("Idle Color", Color) = (1, 1, 1, 1)
        _BottomColorHeight("Bottom Color Height", Float) = -1
        _TopColorHeight("Top Color Height", Float) = -1
        _HeightTexture("Height Texture", 2D) = "gray" {}
        _HeightTS("Height Tiling and Offset", Vector) = (1, 1, 0, 0)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _IdleSmoothness("Idle Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _IdleMetallic("Idle Metallic", Range(0.0, 1.0)) = 0.5
        _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
        _PressureRange("Pressure Range", Float) = 1.0
        _NoiseScale("Noise Scale", Float) = 1.0
        _NoiseSpeed("Noise Speed", Float) = 1.0
        _NoiseAmplitude("Noise Amplitude", Float) = 1.0
        _VoronoiScale("Voronoi Scale", Float) = 5.0
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
                float2 uv: TEXCOORD2;
                half height: TEXCOORD3;
                half disturbance: TEXCOORD4;
                
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 5);
            };

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_HeightTexture);
                SAMPLER(sampler_HeightTexture);
                half4 _HeightTS;
                half3 _BaseColor;
                half3 _BottomColor;
                half3 _TopColor;
                half3 _IdleColor;
                half _HueCenter;
                half _HueDepth;
                half _BottomColorHeight;
                half _TopColorHeight;
                half _Smoothness;
                half _Metallic;
                half _Occlusion;
                half _PressureRange;
                half _NoiseScale;
                half _NoiseSpeed;
                half _NoiseAmplitude;
                half _IdleSmoothness;
                half _IdleMetallic;
                half _VoronoiScale;
            CBUFFER_END

            half4 CalculateNoise(half2 uv)
            {
                return PerlinNoise3DWithDerivative(half3(uv * _NoiseScale, _NoiseSpeed * _Time.x)) * _NoiseAmplitude;
            }
            
            float3 hsvToRgb(float3 hsv)
            {
                float3 hueWave = abs(frac(hsv.xxx + float3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
                
                float3 rgbComponents = saturate(hueWave - 1.0);
                
                return hsv.z * lerp(float3(1.0, 1.0, 1.0), rgbComponents, hsv.y);
            }

            half2 TransformWorldToTexture(half2 positionWS)
            {
                return (positionWS - _HeightTS.zw) / _HeightTS.xy;
            }
            
            half CalculateHeight(half2 positionWS)
            {
                half2 heightUv = TransformWorldToTexture(positionWS);
                half texture_height = SAMPLE_TEXTURE2D_LOD(_HeightTexture, sampler_HeightTexture, heightUv, 0).x * _PressureRange;

                half noise_height = CalculateNoise(positionWS).z;

                return texture_height + noise_height; 
            }

            half CalculateGlitter(half2 renderPos, half disturbance)
            {
                float screenNoise = PerlinNoise3D(float3(float2(int2(renderPos)) / 3.1254, 1));
                float dist = abs(frac(screenNoise + _Time.x * 0.08) - 0.5);
                return smoothstep(0.001, 0, dist) * smoothstep(0.1, 0.2, disturbance);
            }
            
            VertexOutput vert(Attributes input)
            {
                VertexOutput output;

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                half2 heightUv = TransformWorldToTexture(output.positionWS.xz);

                half epsilon = 0.05;

                half disturbance = SAMPLE_TEXTURE2D_LOD(_HeightTexture, sampler_HeightTexture, heightUv, 0).z;

                half height = CalculateHeight(output.positionWS.xz);
                half height_ex = CalculateHeight(output.positionWS.xz + half2(epsilon, 0));
                half height_ez = CalculateHeight(output.positionWS.xz + half2(0, epsilon));

                half2 texture_value_derivative = half2(height_ex - height, height_ez - height) / epsilon;
                
                output.positionWS.y += height;
                output.positionHCS = TransformWorldToHClip(output.positionWS);
                output.normalWS = normalize(half3(-texture_value_derivative.x, 1.0, -texture_value_derivative.y));
                output.uv = input.uv;
                output.height = height;
                output.disturbance = disturbance;

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS, output.vertexSH);
                
                return output;
            }

            half4 frag(VertexOutput input, float4 renderPos: SV_Position) : SV_Target
            {
                half disturbance = smoothstep(0, 0.1, input.disturbance);
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half3 disturbedNormalWS = normalize(input.normalWS);
                half3 disturbedAlbedo = HsvToRgb(float3(input.height * _HueDepth + _HueCenter, 1.0, 1.0));

                disturbedAlbedo += CalculateGlitter(renderPos.xy, input.disturbance);
                float2 voronoiCell;
                VoronoiNoise(input.positionWS.xz * _VoronoiScale, 0.5, voronoiCell);
                voronoiCell /= _VoronoiScale;

                half icedBlockHash = PerlinNoise2D(voronoiCell * 0.5) * 0.5 + 0.5;
                half3 icedBlockDir = normalize(half3(
                    WhiteNoise(float3(icedBlockHash, icedBlockHash, 0)) * 2 - 1,
                    0.1,
                    WhiteNoise(float3(icedBlockHash, icedBlockHash, 3)) * 2 - 1
                ));
                
                half2 heightUv = TransformWorldToTexture(voronoiCell);
                half sellDisturbance = smoothstep(0, 0.1, SAMPLE_TEXTURE2D(_HeightTexture, sampler_HeightTexture, heightUv).z);

                
                half3 albedo = lerp(_IdleColor, disturbedAlbedo, sellDisturbance);
                half3 idleNormal = normalize(disturbedNormalWS + icedBlockDir * 0.02);

                float3 resultColor = FlexusTestCalculateLightingRealistic(
                    viewDirWS,
                    normalize(lerp(idleNormal, disturbedNormalWS, sellDisturbance)),
                    input.positionWS,
                    input.positionHCS,
                    albedo,
                    lerp(_IdleMetallic, _Metallic, disturbance),
                    _Occlusion,
                    lerp(_IdleSmoothness, _Smoothness, disturbance),
                    SAMPLE_GI(input.lightmapUV, input.vertexSH, disturbedNormalWS)
                );

                return half4(resultColor, 1.0);
            }

            ENDHLSL
        }
    }
}
