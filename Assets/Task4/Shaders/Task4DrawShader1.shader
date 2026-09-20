Shader "Custom/Task4DrawShader1"
{
    Properties
    {
        _UvTS("UV Tiling and Offset", Vector) = (1, 1, 0, 0)
        _DrawHeightCenter("Draw Height Center", Vector) = (1, 1, 0, 0)
        _DrawAlphaCenter("Draw Alpha Center", Vector) = (1, 1, 0, 0)
        _DrawRadius("Draw Radius", Float) = 1.0
        _DrawAlphaRadius("Draw Alpha Radius", Float) = 1.0
        _DrawOpacity("Draw Opacity", Range(0, 1)) = 1.0
        _BorderWidth("Border Width", Range(0, 1)) = 0.5
        _BorderAmplitude("Border Amplitude", Range(0, 1)) = 0.5
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha

            HLSLPROGRAM

            #pragma vertex vert
            #pragma fragment frag

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
                float2 positionWS: TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                half3 _DrawHeightCenter;
                half3 _DrawAlphaCenter;
                half4 _UvTS;
                half _DrawRadius;
                half _DrawAlphaRadius;
                half _DrawOpacity;
                half _BorderWidth;
                half _BorderAmplitude;
            CBUFFER_END

            half FadeOffset(half t, half width, half offset)
            {
                return Fade(saturate((t - offset) / width + 0.5));
            }

            VertexOutput vert(Attributes input)
            {
                VertexOutput output;
                
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = input.uv * _UvTS.xy + _UvTS.zw;

                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                half heightDistance = distance(input.positionWS, _DrawHeightCenter.xz) / (_DrawRadius);
                half alphaDistance = distance(input.positionWS, _DrawAlphaCenter.xz) / (_DrawAlphaRadius * 0.5);
                
                half trench = heightDistance - 1;
                half height = lerp(trench, 0, FadeOffset(heightDistance, 0.2 + 3.8 * _BorderAmplitude, 0.9 + 1.1 * _BorderAmplitude));

                half alpha = FadeOffset(alphaDistance, -(1.3 + 0.8 * _BorderWidth), 0.6 + 1.0 * _BorderWidth);

                return half4(height, 0.0, 0.0, alpha * _DrawOpacity);
            }

            ENDHLSL
        }
    }
}
