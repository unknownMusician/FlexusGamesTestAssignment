Shader "Custom/Task1Shader1"
{
    Properties
    {
        [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        _SecondaryColor("Secondary Color", Color) = (1, 1, 1, 1)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _Occlusion("Occlusion", Range(0.0, 1.0)) = 0.5
        _FresnelSmoothstepCenterScale("Fresnel Smoothstep Center Scale", Vector) = (0.5, 1, 0, 0) 
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
                
                DECLARE_LIGHTMAP_OR_SH(lightmapUV, vertexSH, 2);
            };

            CBUFFER_START(UnityPerMaterial)
                half3 _BaseColor;
                half3 _SecondaryColor;
                half _Smoothness;
                half _Metallic;
                half _Occlusion;
                half2 _FresnelSmoothstepCenterScale;
            CBUFFER_END

            half3 CalculateAlbedo(half3 normal, half3 viewDir)
            {
                half smoothstepMin = _FresnelSmoothstepCenterScale.x - _FresnelSmoothstepCenterScale.y * 0.5;
                half smoothstepMax = _FresnelSmoothstepCenterScale.x + _FresnelSmoothstepCenterScale.y * 0.5;
                
                half fresnel = smoothstep(smoothstepMin, smoothstepMax, FlexusTestFresnel(normal, viewDir));

                return lerp(_BaseColor, _SecondaryColor, fresnel);
            }
            
            VertexOutput vert(Attributes input)
            {
                VertexOutput output;
                
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.normalWS = TransformObjectToWorldNormal(input.normalOS.xyz);

                OUTPUT_LIGHTMAP_UV(input.lightmapUV, unity_LightmapST, output.lightmapUV);
                OUTPUT_SH(output.normalWS, output.vertexSH);
                
                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                float3 viewDirWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
                half3 normalWS = normalize(input.normalWS);

                float3 resultColor = FlexusTestCalculateLightingRealistic(
                    viewDirWS,
                    normalWS,
                    input.positionWS,
                    input.positionHCS,
                    CalculateAlbedo(normalWS, viewDirWS),
                    _Metallic,
                    _Occlusion,
                    _Smoothness,
                    SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS)
                );
                
                return half4(resultColor, 1.0);
            }

            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags
            {
                "LightMode" = "ShadowCaster" 
            }
            
            ZWrite On
            ZTest LEqual
            ColorMask 0
            
            HLSLPROGRAM
        
            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment
        
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
        
            #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"
        
            ENDHLSL
        }
    }
}
