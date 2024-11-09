Shader "Custom/toon_water"
{
    Properties
    {
        [HideInInspector]_Foam_Distort_Noise("foam distort noise",2D) = "white"{}
    }
    SubShader
    {
        Tags {
            "RenderPipeline" = "UniversalPipeline"

	        "RenderType"="Transparent"

	        "Queue"="Transparent"
        }
        LOD 200

        Pass
        {
            Name "ForwardLit"
             Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            Blend SrcAlpha OneMinusSrcAlpha
             
            HLSLPROGRAM
            #pragma shader_feature _SMOOTHNESS_ONEMINUS
            #pragma enable_d3d11_debug_symbols

            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile_fog
            
            #pragma vertex vert
            #pragma fragment frag
            #include "Assets/my/Water/shader/Custom/water/toon_water_common.hlsl"
            
            ENDHLSL
        }
    }
    
}
