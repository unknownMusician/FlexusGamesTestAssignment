Shader "Custom/Task4OscillationShader1"
{
    Properties
    {
        [MainTexture] _MainTex("_MainTex", 2D) = "gray" {}
        _Damping("Damping", Float) = 0.1
        _Acceleration("Acceleration", Float) = 1.0
        _SimulationSpeed("Simulation Speed", Float) = 1.0
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" }

        Pass
        {
            Blend One Zero
            BlendOp Add
            
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
                float2 uv: TEXCOORD0;
            };

            CBUFFER_START(UnityPerMaterial)
                TEXTURE2D(_MainTex);
                SAMPLER(sampler_point_clamp_MainTex);
                half _Damping;
                half _Acceleration;
                half _SimulationSpeed;
            CBUFFER_END

            VertexOutput vert(Attributes input)
            {
                VertexOutput output;
                
                output.positionHCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = input.uv;

                return output;
            }

            half4 frag(VertexOutput input) : SV_Target
            {
                half dt = unity_DeltaTime.x * _SimulationSpeed;
                
                half2 textureValue = SAMPLE_TEXTURE2D(_MainTex, sampler_point_clamp_MainTex, input.uv);

                half height = textureValue.x;
                half velocity = textureValue.y;
                half acceleration = -height * _Acceleration;
                
                velocity += acceleration * dt;
                velocity *= exp(-_Damping * dt);

                height += velocity * dt;

                return half4(height, velocity, 0.0, 1.0);
            }

            ENDHLSL
        }
    }
}
