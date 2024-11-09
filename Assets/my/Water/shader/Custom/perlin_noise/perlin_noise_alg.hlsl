#ifndef PERLIN_NOISE_ALG
#define PERLIN_NOISE_ALG



float rand3dTo1d(float3 value, float3 dotDir = float3(12.9898, 78.233, 37.719)){
    //make value smaller to avoid artefacts
    float3 smallValue = sin(value);
    //get scalar value from 3d vector
    float random = dot(smallValue, dotDir);
    //make value more random by making it bigger and then taking the factional part
    random = frac(sin(random) * 143758.5453);
    return random;
}

float rand2dTo1d(float2 value, float2 dotDir = float2(12.9898, 78.233)){
    float2 smallValue = sin(value);
    float random = dot(smallValue, dotDir);
    random = frac(sin(random) * 143758.5453);
    return random;
}

float rand1dTo1d(float3 value, float mutator = 0.546){
    float random = frac(sin(value + mutator) * 143758.5453);
    return random;
}

//to 2d functions

float2 rand3dTo2d(float3 value){
    return float2(
        rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
        rand3dTo1d(value, float3(39.346, 11.135, 83.155))
    );
}

float2 rand2dTo2d(float2 value){
    return float2(
        rand2dTo1d(value, float2(12.989, 78.233)),
        rand2dTo1d(value, float2(39.346, 11.135))
    );
}

float2 rand1dTo2d(float value){
    return float2(
        rand2dTo1d(value, 3.9812),
        rand2dTo1d(value, 7.1536)
    );
}

//to 3d functions

float3 rand3dTo3d(float3 value){
    return float3(
        rand3dTo1d(value, float3(12.989, 78.233, 37.719)),
        rand3dTo1d(value, float3(39.346, 11.135, 83.155)),
        rand3dTo1d(value, float3(73.156, 52.235, 09.151))
    );
}

float3 rand2dTo3d(float2 value){
    return float3(
        rand2dTo1d(value, float2(12.989, 78.233)),
        rand2dTo1d(value, float2(39.346, 11.135)),
        rand2dTo1d(value, float2(73.156, 52.235))
    );
}

float3 rand1dTo3d(float value){
    return float3(
        rand1dTo1d(value, 3.9812),
        rand1dTo1d(value, 7.1536),
        rand1dTo1d(value, 5.7241)
    );
}

float smoothLerp(float a, float b, float t)
{
    float k = pow(t, 5) * 6 - pow(t, 4) * 15 + pow(t, 3) * 10;
    return (1 - k) * a + k * b;
}

float perlinNoise(float3 value)
{
    float3 fraction = frac(value);

    float cellNoiseZ[2];
    [unroll]
    for(int z=0;z<=1;z++){
        float cellNoiseY[2];
        [unroll]
        for(int y=0;y<=1;y++){
            float cellNoiseX[2];
            [unroll]
            for(int x=0;x<=1;x++){
                float3 cell = floor(value) + float3(x, y, z);
                float3 cellDirection = rand3dTo3d(cell) * 2 - 1;
                float3 compareVector = fraction - float3(x, y, z);
                cellNoiseX[x] = dot(cellDirection, compareVector);
            }
            cellNoiseY[y] = smoothLerp(cellNoiseX[0], cellNoiseX[1], fraction.x);
        }
        cellNoiseZ[z] = smoothLerp(cellNoiseY[0], cellNoiseY[1], fraction.y);
    }
    float noise = smoothLerp(cellNoiseZ[0], cellNoiseZ[1], fraction.z);
    return noise+0.5;
}

float fbm_perlinNoise(float3 value,float in_amplitude,float in_frequency,float in_amplitude_attenuation)
{
    float output = 0;
    float amplitude = saturate(in_amplitude);
    float frequency = in_frequency;
    float amplitude_attenuation = saturate(in_amplitude_attenuation);
    for(int i = 0; i<3 ; i++)
    {
        output += perlinNoise(value)*amplitude;
        value *= frequency;
        amplitude *= amplitude_attenuation;
        if(amplitude == 0)break;
    }
    return output;
}


#endif