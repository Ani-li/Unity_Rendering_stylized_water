#pragma enable_d3d11_debug_symbols
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
#pragma multi_compile_fragment _ _SHADOWS_SOFT

struct BaseData
{
    float3 normalView;
    float3 normalDir;
    float3 lightDir;
    float3 viewDir;
    float3 halfDir;
    float3 ws_pos;
    float NdotL;
    float NdotL01;
    float NdotV;
    float NdotH;
};



BaseData base_data;
Light light;

BaseData GetBaseData(
float3 in_normal,
float3 in_viewdir,
float3 vs_normal,
float3 ws_pos
)
{
    BaseData base;
    base.normalDir = in_normal;
    base.lightDir = normalize(light.direction);
    base.viewDir = normalize(in_viewdir);
    base.halfDir = normalize(base.viewDir + base.lightDir);
    base.NdotL = dot(base.normalDir, base.lightDir);
    base.NdotL01 = base.NdotL * 0.5 + 0.5;
    base.NdotV = dot(base.normalDir, base.viewDir);
    base.NdotH = dot(base.normalDir, base.halfDir);
    base.normalView = vs_normal;
    base.ws_pos = ws_pos;
    return base;
}

void GetData_float(
    float3 ws_normal,
    float3 ws_viewdir,
    float3 vs_normal,
    float3 ws_position,
    out float custom_0
)
{
    light = GetMainLight(TransformWorldToShadowCoord(ws_position));
    base_data = GetBaseData(ws_normal, ws_viewdir,vs_normal,ws_position);
    custom_0 = 1;
}