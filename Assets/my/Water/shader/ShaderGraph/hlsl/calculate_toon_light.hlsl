float CalculateLuminance(float3 color)
{
    return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
}

void GetToonLighting_float(
    float custom_in,
    float shadow_factor,
    out float output
)
{
    
    float diffuse = saturate(base_data.NdotL);
    float attenuation = light.distanceAttenuation * light.shadowAttenuation;
    float main_light_strength = CalculateLuminance(light.color);
    float result = diffuse * saturate(attenuation + shadow_factor) * main_light_strength; //重要
#ifdef _ADDITIONAL_LIGHTS
    uint additionLightCount= GetAdditionalLightsCount();
    for(uint iu = 0; iu < additionLightCount; iu++)
    {
        Light addLight = GetAdditionalLight(iu,base_data.ws_pos);
        float nl = dot(addLight.direction,base_data.normalDir);
        float nl01 = nl * 0.5 + 0.5;
        float light_strength = CalculateLuminance(addLight.color);
        result = max(saturate(nl01) * addLight.distanceAttenuation * light_strength,result); //重要
    }
#endif
    output = saturate(result);
    
}




