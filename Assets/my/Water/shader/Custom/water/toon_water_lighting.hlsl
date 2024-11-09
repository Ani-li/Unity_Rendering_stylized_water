#ifndef TOON_WATER_LIGHTING
#define TOON_WATER_LIGHTING

struct custom_surfaceData
{
    half3 albedo;
    half3 specular;
    half metallic;
    half smoothness;
    half3 normalTS;
    half occlusion;
};

struct custom_inputData
{
    float3 positionWS;
    float4 positionCS;
    half3 normalWS;
    half3 viewDirectionWS;
    float2 normalizedScreenSpaceUV;
    half3x3 tangentToWorld;
    float4 shadowCoord;
    half3 bakeGI;
};

custom_surfaceData Create_SurfaceData(
    float3 in_albedo,
    float3 in_specular,
    float in_metallic,
    float in_smoothness,
    float3 in_normalTS
)
{
    custom_surfaceData output = (custom_surfaceData)0;
    output.albedo = in_albedo;
    output.specular = in_specular;
    output.metallic = in_metallic;
    output.smoothness = in_smoothness;
    output.normalTS = in_normalTS;
    output.occlusion = 1;
    return output;
}

custom_inputData Create_InputData(Varyings input, custom_surfaceData surfaceData)
{
    custom_inputData output = (custom_inputData)0;
    
    float crossSign = (input.tangentWS.w > 0.0 ? 1.0 : -1.0) * GetOddNegativeScale();
    float3 bitangent = crossSign * cross(input.normalWS.xyz,input.tangentWS.xyz);
    
    output.positionWS = input.positionWS;
    output.tangentToWorld = half3x3(input.tangentWS.xyz,bitangent.xyz,input.normalWS.xyz);
    output.normalWS = TransformTangentToWorld(surfaceData.normalTS,output.tangentToWorld);
    output.normalWS = normalize(output.normalWS);
    output.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);
    output.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    output.positionCS = input.positionCS;
    output.shadowCoord = input.shadowCoord;
    output.bakeGI = half3(unity_SHAr.w, unity_SHAg.w, unity_SHAb.w);
    return output;
}

half3 Simple_Specular_BRDF(custom_inputData input_data,custom_surfaceData surface_data, Light main_light)
{
    float NdotL = saturate(dot(input_data.normalWS,main_light.direction));
    float3 halfDir = SafeNormalize(main_light.direction + input_data.viewDirectionWS);
    float NdotH = dot(input_data.normalWS,halfDir);
    float NdotV = dot(input_data.normalWS,input_data.viewDirectionWS);
    
    //attenuation
    half3 radiance = main_light.color * (main_light.distanceAttenuation * main_light.shadowAttenuation * NdotL);

    //specular term
    float denominator = 4 * saturate(dot(input_data.normalWS,main_light.direction)) * saturate(dot(input_data.normalWS,input_data.viewDirectionWS)) + 0.0001;
    
    float d1 = (2 / (surface_data.smoothness * surface_data.smoothness + 0.000001)) - 2;
    float d2 = 1 / (PI * surface_data.smoothness * surface_data.smoothness  + 0.000001);
    float D = d2 * pow(saturate(NdotH),d1);

    float F = surface_data.specular + (1 - surface_data.specular) * pow(saturate(1 - dot(input_data.viewDirectionWS,halfDir)),5);

    float g1 = surface_data.smoothness * 2 / PI;
    float gl = saturate(NdotL) * (1-g1) + g1;
    float gv = saturate(NdotV) * (1-g1) + g1;
    float G = (1.0/(gl * gv + 1e-5f))*0.25; /// 这个你后面还是好好推导下吧
    
    float specular = D * F * G/ denominator;
    
    half3 output = specular * radiance;
    return output;
}


#endif