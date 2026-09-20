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
            
            half SampleHueByHeight(half height)
            {
                return height * _HueDepth + _HueCenter;
                
                half centerHeight = (_TopColorHeight + _BottomColorHeight) * 0.5;

                height = (height - centerHeight) / (_TopColorHeight - centerHeight);
                height = clamp(height, -1, 1);

                half3 topColor = lerp(_BaseColor, _TopColor, saturate(height));
                half3 bottomColor = lerp(_BaseColor, _BottomColor, saturate(-height));
                return lerp(bottomColor, topColor, step(0, height));
            }

            half CalculateHeight(half2 positionWS)
            {
                half2 heightUv = (positionWS - _HeightTS.zw) / _HeightTS.xy;
                half texture_height = SAMPLE_TEXTURE2D_LOD(_HeightTexture, sampler_HeightTexture, heightUv, 0).x * _PressureRange;

                half noise_height = CalculateNoise(positionWS).z;

                return texture_height + noise_height; 
            }
            
            VertexOutput vert(Attributes input)
            {
                VertexOutput output;

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                half2 heightUv = (output.positionWS.xz - _HeightTS.zw) / _HeightTS.xy;

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
                half3 normalWS = normalize(input.normalWS);
                half3 albedo = HsvToRgb(float3(SampleHueByHeight(input.height), 1.0, 1.0));
                albedo = lerp(_IdleColor, albedo, disturbance);

                half noiseHash0 = WhiteNoise(float3(input.positionWS.xz, 100));
                half noiseHash1 = WhiteNoise(float3(input.positionWS.xz, 110));

                
                float screenNoise = PerlinNoise3D(float3(float2(int2(renderPos.xy)) / 3.1254, 1));
                // screenNoise += WhiteNoise(float3(float2(int2(renderPos.xy)), 2));
                // screenNoise += WhiteNoise(float3(float2(int2(renderPos.xy)), 3));
                // screenNoise += WhiteNoise(float3(float2(int2(renderPos.xy)), 4));
                // screenNoise += WhiteNoise(float3(float2(int2(renderPos.xy)), 5));
                float dist = abs(frac(screenNoise + _Time.x * 0.01) - 0.5);
                
                albedo += smoothstep(0.0001, 0, dist) * smoothstep(0.2, 0.4, input.disturbance);
                float2 voronoiCell;
                half voronoiDist = VoronoiNoise(input.positionWS.xz * 5, 0.5, voronoiCell);
                voronoiCell /= 5;
                half3 glitterDir = normalize(half3(
                    WhiteNoise(float3(voronoiCell, 0)) * 2 - 1,
                    0.1,
                    WhiteNoise(float3(voronoiCell, 3)) * 2 - 1
                ));

                //half icedBlockHash = PerlinNoise2D(voronoiCell * 0.1 + float2(_Time.x * 10, 3)) * 0.5 + 0.5;
                half icedBlockHash = PerlinNoise2D(voronoiCell * 0.1) * 0.5 + 0.5;
                
                half3 icedBlockDir = normalize(half3(
                    WhiteNoise(float3(icedBlockHash, icedBlockHash, 0)) * 2 - 1,
                    0.1,
                    WhiteNoise(float3(icedBlockHash, icedBlockHash, 3)) * 2 - 1
                ));

                
                half2 heightUv = (voronoiCell - _HeightTS.zw) / _HeightTS.xy;
                half sellDisturbance = smoothstep(0, 0.1, SAMPLE_TEXTURE2D(_HeightTexture, sampler_HeightTexture, heightUv).z);
                //sellDisturbance = smoothstep(0.01, 0.012, sellDisturbance);

                
                albedo = lerp(_IdleColor, albedo, sellDisturbance);

                
                //return PerlinNoise2D(voronoiCell * 0.1 + float2(_Time.x * 10, 3)) * 0.5 + 0.5;
                //return PerlinNoise2D(voronoiCell + float2(_Time.x * 10, 0));

                //return step(voronoiDist, 1.5) * smoothstep(0.5, 1, dot(glitterDir, viewDirWS));
                //return step(voronoiDist, 0.05) * smoothstep(0.8, 1, dot(glitterDir, viewDirWS));
                ;
                //return step(noiseHash0, 0.0) * step(noiseHash1, 0.2) * smoothstep(0.0, 1.0, dot(glitterDir, viewDirWS));
                //return smoothstep(0.5, 0, abs(dot(viewDirWS, normalWS) - noiseHash0 * 100));
                if (1 < 0.001)
                {
                    //return half4(1, 1, 1, 1);
                }

                half3 calmNormal = normalize(normalWS + icedBlockDir * 0.02);

                float3 resultColor = FlexusTestCalculateLightingRealistic(
                    viewDirWS,
                    normalize(lerp(calmNormal, normalWS, sellDisturbance)),
                    input.positionWS,
                    input.positionHCS,
                    albedo,
                    lerp(_IdleMetallic, _Metallic, disturbance),
                    _Occlusion,
                    lerp(_IdleSmoothness, _Smoothness, disturbance),
                    SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS)
                );

                return half4(resultColor, 1.0);
            }

            ENDHLSL
        }
    }
}
