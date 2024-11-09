#ifndef TOON_WATER_COMMON
#define TOON_WATER_COMMON



struct Attributes
{
    float4 positionOS          : POSITION;
    float3 normalOS            : NORMAL;
    float4 tangentOS           : TANGENT;
    float2 texcoord            : TEXCOORD0;
};

struct Varyings
{
    float2 uv                  : TEXCOORD0;
    float3 positionWS          : TEXCOORD1;
    float3 normalWS            : TEXCOORD2;
    half4 tangentWS            : TEXCOORD3;   // xyz: tangent, w: sign
    float4 shadowCoord         : TEXCOORD4;
    float fogFactor            : TEXCOORD5; 
    float4 positionCS          : SV_POSITION;
};

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Assets/my/Water/shader/Custom/water/toon_water_input.hlsl"
#include "Assets/my/Water/shader/Custom/water/toon_water_lighting.hlsl"

float4 Calculate_Foam(float depth,float2 texcoord)
{
    float noise_origin = SAMPLE_TEXTURE2D(_Water_Bump_Map,sampler_LinearRepeat,texcoord * _foam_01_distort_noise_scale);
    float foam_scope = 1 - saturate(depth/_foam_scope);

    float foam_1 = _foam_01_width * sin(_foam_01_interval * depth - _Time.y * _foam_01_speed);
    foam_1 = step(1,foam_1);
    foam_1 *= saturate(noise_origin * 2 - 1);
    foam_1 = step(0.1,foam_1);

    float foam_2 = 1 - saturate((depth+sin(noise_origin*2*PI) * _foam_02_distort_strength)/_foam_02_width);
    foam_2 = step(0.1,foam_2);

    float foam = saturate(foam_1 + foam_2);
    foam *= foam_scope;
    
    return float4(foam * _foam_color,foam);
}
float3 Calculate_SSS(float depth,Light light,custom_inputData input_data)
{
    float3 L = light.direction;
    float3 V=  input_data.viewDirectionWS;
    float3 N = input_data.normalWS;

    float3 H = normalize(L+N * _sss_distort);
    float VdotH = pow(saturate(dot(V,-H)),_sss_power) * _sss_scale;
    float d = depth/_max_visibility;
    float3 I = _sss_strength * (VdotH + input_data.bakeGI) * d;

    float4 color_ramp = SAMPLE_TEXTURE2D(_Water_Absorption_Scatter_Map,sampler_PointClamp,float2(depth/_max_visibility,1));
    
    return light.color * I * color_ramp.rgb;
}

float3 Calculate_Reflection(custom_inputData input_data)
{
    float3 WS_vertex_normal = TransformTangentToWorldDir(float3(0,0,1),input_data.tangentToWorld);
    float3 VS_vertex_normal = TransformWorldToViewDir(WS_vertex_normal);
    
    float3 VS_normal = TransformWorldToViewDir(input_data.normalWS);

    float2 sceneUV_distort = (VS_vertex_normal.xy - VS_normal.xy) * _reflective_distort;
    float3 reflect_color = SAMPLE_TEXTURE2D(_Planar_Reflection_Texture,sampler_LinearRepeat,input_data.normalizedScreenSpaceUV + sceneUV_distort);
    return reflect_color;
}

float3 Calculate_Refraction(float depth,custom_inputData input_data)
{
    float3 output;
    //ramp
    float4 color_ramp = SAMPLE_TEXTURE2D(_Water_Absorption_Scatter_Map,sampler_PointClamp,float2(depth/_max_visibility,0));

    //refraction
    float air_ior = 1.0f;
    float water_ior = 1.33f;
    float3 normal_VS = normalize(TransformWorldToViewDir(input_data.normalWS));
    float2 sceneUV_distort = input_data.normalizedScreenSpaceUV + normal_VS.xy * (water_ior - air_ior) * saturate((depth*1.0/_max_visibility)) * _refractive_strength * 0.05;;
    float3 scene_color = SAMPLE_TEXTURE2D_LOD(_CameraOpaqueTexture,sampler_LinearRepeat,sceneUV_distort,0);
    
    output = lerp(scene_color,color_ramp.rgb,color_ramp.a);
    
    return output;
}

float2 Calculate_Depth(custom_inputData input_data)
{
    float3 position_VS = TransformWorldToView(input_data.positionWS);
    float d = length(position_VS.xyz/position_VS.z);
    float rawD = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,sampler_LinearClamp,input_data.normalizedScreenSpaceUV);
    float bottom_depth_VS = LinearEyeDepth(rawD,_ZBufferParams) * d;
    
    float water_depth_VS = length(GetCameraPositionWS().xyz - input_data.positionWS);
    float diff_depth_VS = abs(bottom_depth_VS - water_depth_VS);

    return float2(diff_depth_VS,0);
}

float3 Noise_To_Normal(float2 texcoord)
{
    float uv_offset = 1.0/3750;
    float noise_origin = SAMPLE_TEXTURE2D(_Water_Bump_Map,sampler_LinearRepeat,texcoord);
    float noise_x = SAMPLE_TEXTURE2D(_Water_Bump_Map,sampler_LinearRepeat,texcoord+float2(uv_offset,0));
    float noise_y = SAMPLE_TEXTURE2D(_Water_Bump_Map,sampler_LinearRepeat,texcoord+float2(0,uv_offset));
    float3 s = float3(1,0,(noise_x - noise_origin)*_normal_strength);
    float3 t = float3(0,1,(noise_y - noise_origin)*_normal_strength);
    float3 normals = normalize(cross(s,t));
    return normals;
}

Varyings vert(Attributes input)
{
    Varyings output = (Varyings)0;

    VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS,input.tangentOS);

    real sign = input.tangentOS.w * GetOddNegativeScale();
    half4 tangentWS = half4(normalInput.tangentWS,sign);
    
    output.uv = input.texcoord;
    output.normalWS = normalInput.normalWS;
    output.tangentWS = tangentWS;
    output.positionWS = vertexInput.positionWS;
    output.positionCS = vertexInput.positionCS;
    output.shadowCoord = GetShadowCoord(vertexInput);
    output.fogFactor = ComputeFogFactor(vertexInput.positionCS.z);
    return output;
}

void frag(Varyings IN,out half4 finalColor : SV_Target0)
{
    float3 normalTS = Noise_To_Normal(IN.uv);
    custom_surfaceData surface_data = Create_SurfaceData(float3(0.5,0.5,0.5),_specular,_metallic,_smoothness,normalTS);
    custom_inputData input_data = Create_InputData(IN,surface_data);
    Light mainLight = GetMainLight(TransformWorldToShadowCoord(IN.positionWS));

    float depth = Calculate_Depth(input_data).r;
    float3 refraction = Calculate_Refraction(depth,input_data);
    float3 reflection = Calculate_Reflection(input_data);
    float Fresnel = saturate(pow(1.0 - dot(input_data.normalWS,input_data.viewDirectionWS),5));
    float3 specular = Simple_Specular_BRDF(input_data,surface_data,mainLight);
    float3 sss = Calculate_SSS(depth,mainLight,input_data);
    float4 foam = Calculate_Foam(depth,IN.uv);
#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for(uint lightIndex = 0 ; lightIndex < pixelLightCount ; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex,input_data.positionWS);
        specular += Simple_Specular_BRDF(input_data,surface_data,light);
        sss += Calculate_SSS(depth,light,input_data);
    }
#endif
    

    float3 water_color = lerp(refraction,reflection,Fresnel) + specular + sss;
    float3 foam_color = foam.rgb;
    float3 final_color = lerp(water_color,foam_color,foam.a);
    final_color.rgb = MixFog(final_color.rgb,IN.fogFactor);
    finalColor = float4(final_color,1);
    

}

#endif