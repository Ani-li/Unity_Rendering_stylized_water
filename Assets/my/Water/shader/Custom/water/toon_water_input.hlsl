#ifndef TOON_WATER_INPUT
#define TOON_WATER_INPUT

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

float _specular;
float _metallic;
float _smoothness;
float _normal_strength;
float _max_visibility;
float _refractive_strength;
float _reflective_distort;
float _sss_strength;
float _sss_distort;
float _sss_power;
float _sss_scale;
float3 _foam_color;
float _foam_scope;
float _foam_01_width;
float _foam_01_interval;
float _foam_01_speed;
float _foam_01_distort_noise_scale;
float _foam_02_width;
float _foam_02_distort_strength;
TEXTURE2D(_Water_Bump_Map);
TEXTURE2D(_CameraDepthTexture);
TEXTURE2D(_Water_Absorption_Scatter_Map);
TEXTURE2D(_CameraOpaqueTexture);
TEXTURE2D(_Planar_Reflection_Texture);


#endif