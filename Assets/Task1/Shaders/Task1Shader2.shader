Shader "Custom/Task1Shader2"
{
    Properties
    {
        [HDR] [MainColor] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
        [HDR] _FresnelColor("Fresnel Color", Color) = (1, 1, 1, 1)
        _Smoothness("Smoothness", Range(0.0, 1.0)) = 0.5
        _Metallic("Metallic", Range(0.0, 1.0)) = 0.5
        _FresnelPow("Fresnel Power", Float) = 1.0
        _FresnelSmoothstep("Fresnel Smoothstep", Vector) = (1, 1, 0, 0)
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
                half4 _BaseColor;
                half4 _FresnelColor;
                half _Smoothness;
                half _Metallic;
                half _FresnelPow;
                half2 _FresnelSmoothstep;
            CBUFFER_END

            half3 Fresnel(half3 normal, half3 viewDir)
            {
                half fresnel = saturate(half(1.0) - dot(normal, viewDir));

                fresnel = pow(fresnel, _FresnelPow);

                return fresnel;
            }

            half3 CalculateAlbedo(half3 normal, half3 viewDir)
            {
                half fresnel = Fresnel(normal, viewDir);
                fresnel = smoothstep(_FresnelSmoothstep.x - _FresnelSmoothstep.y * 0.5, _FresnelSmoothstep.x + _FresnelSmoothstep.y * 0.5, fresnel);
                return lerp(_BaseColor, _FresnelColor, fresnel);
            }
            
            half3 CalculateColorFromLight(
                Light light,
                float3 viewDirWS,
                float3 normalWS,
                float3 positionWS,
                float4 positionCS,
                half3 gi
            )
            {
                half3 colorAlbedo = CalculateAlbedo(normalWS, viewDirWS);
                half3 colorDiffuse = saturate(dot(light.direction, normalWS)) * colorAlbedo;// * (half(1.0) - _Smoothness);

                half specularSmoothness = exp2(10 * _Smoothness + 1);
                half3 colorSpecular = LightingSpecular(light.color, light.direction, normalWS, viewDirWS, 20.0, specularSmoothness) * _Smoothness;

                float3 reflectDirWS = reflect(-viewDirWS, normalWS);
                half3 colorGlossy = GlossyEnvironmentReflection(reflectDirWS, positionWS, half(1.0) - _Smoothness, half(1.0)) * _Smoothness;

                half3 colorReflect = (colorSpecular + colorGlossy) * lerp(half3(1.0, 1.0, 1.0), colorAlbedo, _Metallic);
                
                return colorAlbedo + colorReflect;
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
                half3 gi = SAMPLE_GI(input.lightmapUV, input.vertexSH, normalWS);

                half3 colorResult;

                Light lightMain = GetMainLight();
                
                float3 resultColor = CalculateColorFromLight(lightMain, viewDirWS, normalWS, input.positionWS, input.positionHCS, gi);

                uint lightsAdditionalCount = GetAdditionalLightsCount();
                for (uint i = 0; i < lightsAdditionalCount; ++i)
                {
                    Light lightAdditional = GetAdditionalLight(i, input.positionWS);
                    
                    resultColor += CalculateColorFromLight(lightAdditional, viewDirWS, normalWS, input.positionWS, input.positionHCS, gi);
                }
                
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
