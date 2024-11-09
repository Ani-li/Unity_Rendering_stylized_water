Shader "Custom/perlin_noise"
{
    Properties
    {
        
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversialPipeline"}
        LOD 200
        
        Pass
        {
            Name "ToonWaterNoise"
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Assets/my/Water/shader/Custom/perlin_noise/perlin_noise_alg.hlsl"
            #include "Assets/my/Water/shader/Custom/perlin_noise/perlin_noise_input.hlsl"

            struct Attributes
            {
                float4 position : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };
            
            #pragma vertex vert
            #pragma fragment frag
            

            float Generate_Noise(float2 texcoord)
            {
                float noise1 = fbm_perlinNoise(float3(texcoord * _noise_01_size,_Time.x * _noise_01_speed),_noise_01_fbm_amplitude,_noise_01_fbm_frequency,_noise_01_fbm_amplitude_attenuation);
                float noise2 = fbm_perlinNoise(float3(texcoord * _noise_02_size,_Time.x * _noise_02_speed),_noise_02_fbm_amplitude,_noise_02_fbm_frequency,_noise_02_fbm_amplitude_attenuation);
                float noise = smoothLerp(0,1,(noise1+noise2)/2);
                return noise;
            }

            Varyings vert(Attributes IN)
            {
                Varyings OUT;
                VertexPositionInputs vertex_position_inputs = GetVertexPositionInputs(IN.position.xyz);

                OUT.positionCS = vertex_position_inputs.positionCS;
                OUT.uv = IN.uv;
                return OUT;
            }
            
            float frag(Varyings IN):SV_Target{
                float noise = Generate_Noise(IN.uv);
                return noise;
            }
            ENDHLSL
        }
        
    }
    
}
