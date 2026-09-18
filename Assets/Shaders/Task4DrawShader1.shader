Shader "Custom/Task4DrawShader1"
{
    Properties
    {
        _UvTS("UV Tiling and Offset", Vector) = (1, 1, 0, 0)
        _DrawHeightCenter("Draw Height Center", Vector) = (1, 1, 0, 0)
        _DrawAlphaCenter("Draw Alpha Center", Vector) = (1, 1, 0, 0)
        _AlphaSmoothing("Alpha Smoothing", Float) = 0.1
        _DrawRadius("Draw Radius", Float) = 1.0
        _DrawAlphaRadius("Draw Alpha Radius", Float) = 1.0
        _DrawOpacity("Draw Opacity", Float) = 1.0
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
            #include "Assets/Shaders/noise.hlsl"

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
                half _AlphaSmoothing;
            CBUFFER_END

            VertexOutput vert(Attributes input)
            {
                VertexOutput output;
                
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.positionWS = input.uv * _UvTS.xy + _UvTS.zw;

                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                half alphaUnnormalized = distance(input.positionWS, _DrawAlphaCenter.xz) / (_DrawAlphaRadius * 2.0);
                half alpha = smoothstep(alphaUnnormalized - _AlphaSmoothing * 0.5, alphaUnnormalized + _AlphaSmoothing * 0.5, 0.5);
                
                half dist = distance(input.positionWS, _DrawHeightCenter.xz) / (_DrawRadius * 2.0);
                half height = Fade(saturate(dist)) - 1.0;

                return half4(height, 0.0, 0.0, alpha * _DrawOpacity);
            }

            ENDHLSL
        }
    }
}
