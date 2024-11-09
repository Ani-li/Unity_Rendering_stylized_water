Shader"Custom/ToonTerrain"
{
    Properties
    {
        _ShadowFade("Shadow Fade",Range(0,1)) = 0
        [HideInInspector]_gradient_map("gradient",2D) = "white"{}
        
        [Space(50)]
        [ToggleUI] _EnableHeightBlend("EnableHeightBlend", Float) = 0.0
        _HeightTransition("Height Transition", Range(0, 1.0)) = 0.0
        // Layer count is passed down to guide height-blend enable/disable, due
        // to the fact that heigh-based blend will be broken with multipass.
        [HideInInspector] [PerRendererData] _NumLayersCount ("Total Layer Count", Float) = 1.0

        // set by terrain engine
        [HideInInspector] _Control("Control (RGBA)", 2D) = "red" {}
        [HideInInspector] _Splat3("Layer 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Splat2("Layer 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Splat1("Layer 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Splat0("Layer 0 (R)", 2D) = "grey" {}
        [HideInInspector] _Normal3("Normal 3 (A)", 2D) = "bump" {}
        [HideInInspector] _Normal2("Normal 2 (B)", 2D) = "bump" {}
        [HideInInspector] _Normal1("Normal 1 (G)", 2D) = "bump" {}
        [HideInInspector] _Normal0("Normal 0 (R)", 2D) = "bump" {}
        [HideInInspector] _Mask3("Mask 3 (A)", 2D) = "grey" {}
        [HideInInspector] _Mask2("Mask 2 (B)", 2D) = "grey" {}
        [HideInInspector] _Mask1("Mask 1 (G)", 2D) = "grey" {}
        [HideInInspector] _Mask0("Mask 0 (R)", 2D) = "grey" {}
        [HideInInspector][Gamma] _Metallic0("Metallic 0", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic1("Metallic 1", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic2("Metallic 2", Range(0.0, 1.0)) = 0.0
        [HideInInspector][Gamma] _Metallic3("Metallic 3", Range(0.0, 1.0)) = 0.0
        [HideInInspector] _Smoothness0("Smoothness 0", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness1("Smoothness 1", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness2("Smoothness 2", Range(0.0, 1.0)) = 0.5
        [HideInInspector] _Smoothness3("Smoothness 3", Range(0.0, 1.0)) = 0.5

        // used in fallback on old cards & base map
        [HideInInspector] _MainTex("BaseMap (RGB)", 2D) = "grey" {}
        [HideInInspector] _BaseColor("Main Color", Color) = (1,1,1,1)

        [HideInInspector] _TerrainHolesTexture("Holes Map (RGB)", 2D) = "white" {}

        [ToggleUI] _EnableInstancedPerPixelNormal("Enable Instanced per-pixel normal", Float) = 1.0
    }

    HLSLINCLUDE

    #pragma multi_compile_fragment __ _ALPHATEST_ON

    ENDHLSL

    SubShader
    {
        Tags { "Queue" = "Geometry-100" "RenderType" = "Opaque" "RenderPipeline" = "UniversalPipeline" "UniversalMaterialType" = "Lit" "IgnoreProjector" = "False" "TerrainCompatible" = "True"}

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
            HLSLPROGRAM
            #pragma target 3.0

            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile_fragment _ _SCREEN_SPACE_OCCLUSION
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #pragma multi_compile_fragment _ _LIGHT_LAYERS
            #pragma multi_compile_fragment _ _LIGHT_COOKIES
            #pragma multi_compile _ _FORWARD_PLUS
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fog
            #pragma multi_compile_fragment _ DEBUG_DISPLAY
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local_fragment _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local_fragment _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL

            #ifndef UNIVERSAL_TERRAIN_LIT_INPUT_INCLUDED
            #define UNIVERSAL_TERRAIN_LIT_INPUT_INCLUDED

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                half4 _BaseColor;
                half _Cutoff;
                //custom
                float _ShadowFade;
                //custom
            CBUFFER_END
            TEXTURE2D(_gradient_map);
            
            #define _Surface 0.0 // Terrain is always opaque

            CBUFFER_START(_Terrain)
           
                half _NormalScale0, _NormalScale1, _NormalScale2, _NormalScale3;
                half _Metallic0, _Metallic1, _Metallic2, _Metallic3;
                half _Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3;
                half4 _DiffuseRemapScale0, _DiffuseRemapScale1, _DiffuseRemapScale2, _DiffuseRemapScale3;
                half4 _MaskMapRemapOffset0, _MaskMapRemapOffset1, _MaskMapRemapOffset2, _MaskMapRemapOffset3;
                half4 _MaskMapRemapScale0, _MaskMapRemapScale1, _MaskMapRemapScale2, _MaskMapRemapScale3;

                float4 _Control_ST;
                float4 _Control_TexelSize;
                half _DiffuseHasAlpha0, _DiffuseHasAlpha1, _DiffuseHasAlpha2, _DiffuseHasAlpha3;
                half _LayerHasMask0, _LayerHasMask1, _LayerHasMask2, _LayerHasMask3;
                half4 _Splat0_ST, _Splat1_ST, _Splat2_ST, _Splat3_ST;
                half _HeightTransition;
                half _NumLayersCount;

                #ifdef UNITY_INSTANCING_ENABLED
                float4 _TerrainHeightmapRecipSize;   // float4(1.0f/width, 1.0f/height, 1.0f/(width-1), 1.0f/(height-1))
                float4 _TerrainHeightmapScale;       // float4(hmScale.x, hmScale.y / (float)(kMaxHeight), hmScale.z, 0.0f)
                #endif
                #ifdef SCENESELECTIONPASS
                int _ObjectId;
                int _PassValue;
                #endif
            CBUFFER_END


            TEXTURE2D(_Control);    SAMPLER(sampler_Control);
            TEXTURE2D(_Splat0);     SAMPLER(sampler_Splat0);
            TEXTURE2D(_Splat1);
            TEXTURE2D(_Splat2);
            TEXTURE2D(_Splat3);

            #ifdef _NORMALMAP
            TEXTURE2D(_Normal0);     SAMPLER(sampler_Normal0);
            TEXTURE2D(_Normal1);
            TEXTURE2D(_Normal2);
            TEXTURE2D(_Normal3);
            #endif

            #ifdef _MASKMAP
            TEXTURE2D(_Mask0);      SAMPLER(sampler_Mask0);
            TEXTURE2D(_Mask1);
            TEXTURE2D(_Mask2);
            TEXTURE2D(_Mask3);
            #endif

            TEXTURE2D(_MainTex);       SAMPLER(sampler_MainTex);
            TEXTURE2D(_SpecGlossMap);  SAMPLER(sampler_SpecGlossMap);
            TEXTURE2D(_MetallicTex);   SAMPLER(sampler_MetallicTex);

            #if defined(UNITY_INSTANCING_ENABLED) && defined(_TERRAIN_INSTANCED_PERPIXEL_NORMAL)
            #define ENABLE_TERRAIN_PERPIXEL_NORMAL
            #endif

            #ifdef UNITY_INSTANCING_ENABLED
            TEXTURE2D(_TerrainHeightmapTexture);
            TEXTURE2D(_TerrainNormalmapTexture);
            SAMPLER(sampler_TerrainNormalmapTexture);
            #endif

            UNITY_INSTANCING_BUFFER_START(Terrain)
            UNITY_DEFINE_INSTANCED_PROP(float4, _TerrainPatchInstanceData)  // float4(xBase, yBase, skipScale, ~)
            UNITY_INSTANCING_BUFFER_END(Terrain)

            #ifdef _ALPHATEST_ON
            TEXTURE2D(_TerrainHolesTexture);
            SAMPLER(sampler_TerrainHolesTexture);

            void ClipHoles(float2 uv)
            {
                float hole = SAMPLE_TEXTURE2D(_TerrainHolesTexture, sampler_TerrainHolesTexture, uv).r;
                clip(hole == 0.0f ? -1 : 1);
            }
            #endif

            half4 SampleMetallicSpecGloss(float2 uv, half albedoAlpha)
            {
                half4 specGloss;
                specGloss = SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, uv);
                specGloss.a = albedoAlpha;
                return specGloss;
            }

            inline void InitializeStandardLitSurfaceData(float2 uv, out SurfaceData outSurfaceData)
            {
                outSurfaceData = (SurfaceData)0;
                half4 albedoSmoothness = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                outSurfaceData.alpha = 1;

                half4 specGloss = SampleMetallicSpecGloss(uv, albedoSmoothness.a);
                outSurfaceData.albedo = albedoSmoothness.rgb;

                outSurfaceData.metallic = specGloss.r;
                outSurfaceData.specular = half3(0.0h, 0.0h, 0.0h);

                outSurfaceData.smoothness = specGloss.a;
                outSurfaceData.normalTS = SampleNormal(uv, TEXTURE2D_ARGS(_BumpMap, sampler_BumpMap));
                outSurfaceData.occlusion = 1;
                outSurfaceData.emission = 0;
            }


            void TerrainInstancing(inout float4 positionOS, inout float3 normal, inout float2 uv)
            {
            #ifdef UNITY_INSTANCING_ENABLED
                float2 patchVertex = positionOS.xy;
                float4 instanceData = UNITY_ACCESS_INSTANCED_PROP(Terrain, _TerrainPatchInstanceData);

                float2 sampleCoords = (patchVertex.xy + instanceData.xy) * instanceData.z; // (xy + float2(xBase,yBase)) * skipScale
                float height = UnpackHeightmap(_TerrainHeightmapTexture.Load(int3(sampleCoords, 0)));

                positionOS.xz = sampleCoords * _TerrainHeightmapScale.xz;
                positionOS.y = height * _TerrainHeightmapScale.y;

            #ifdef ENABLE_TERRAIN_PERPIXEL_NORMAL
                normal = float3(0, 1, 0);
            #else
                normal = _TerrainNormalmapTexture.Load(int3(sampleCoords, 0)).rgb * 2 - 1;
            #endif
                uv = sampleCoords * _TerrainHeightmapRecipSize.zw;
            #endif
            }

            void TerrainInstancing(inout float4 positionOS, inout float3 normal)
            {
                float2 uv = { 0, 0 };
                TerrainInstancing(positionOS, normal, uv);
            }
            #endif


            
            #ifndef UNIVERSAL_TERRAIN_LIT_PASSES_INCLUDED
            #define UNIVERSAL_TERRAIN_LIT_PASSES_INCLUDED

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DBuffer.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 texcoord : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct Varyings
            {
                float4 uvMainAndLM              : TEXCOORD0; // xy: control, zw: lightmap
                #ifndef TERRAIN_SPLAT_BASEPASS
                    float4 uvSplat01                : TEXCOORD1; // xy: splat0, zw: splat1
                    float4 uvSplat23                : TEXCOORD2; // xy: splat2, zw: splat3
                #endif

                #if defined(_NORMALMAP) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
                    half4 normal                    : TEXCOORD3;    // xyz: normal, w: viewDir.x
                    half4 tangent                   : TEXCOORD4;    // xyz: tangent, w: viewDir.y
                    half4 bitangent                 : TEXCOORD5;    // xyz: bitangent, w: viewDir.z
                #else
                    half3 normal                    : TEXCOORD3;
                    half3 vertexSH                  : TEXCOORD4; // SH
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    half4 fogFactorAndVertexLight   : TEXCOORD6; // x: fogFactor, yzw: vertex light
                #else
                    half  fogFactor                 : TEXCOORD6;
                #endif

                float3 positionWS               : TEXCOORD7;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    float4 shadowCoord              : TEXCOORD8;
                #endif

            #if defined(DYNAMICLIGHTMAP_ON)
                float2 dynamicLightmapUV        : TEXCOORD9;
            #endif

                float4 clipPos                  : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            void InitializeInputData(Varyings IN, half3 normalTS, out InputData inputData)
            {
                inputData = (InputData)0;

                inputData.positionWS = IN.positionWS;
                inputData.positionCS = IN.clipPos;

                #if defined(_NORMALMAP) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
                    half3 viewDirWS = half3(IN.normal.w, IN.tangent.w, IN.bitangent.w);
                    inputData.tangentToWorld = half3x3(-IN.tangent.xyz, IN.bitangent.xyz, IN.normal.xyz);
                    inputData.normalWS = TransformTangentToWorld(normalTS, inputData.tangentToWorld);
                    half3 SH = 0;
                #elif defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                    float2 sampleCoords = (IN.uvMainAndLM.xy / _TerrainHeightmapRecipSize.zw + 0.5f) * _TerrainHeightmapRecipSize.xy;
                    half3 normalWS = TransformObjectToWorldNormal(normalize(SAMPLE_TEXTURE2D(_TerrainNormalmapTexture, sampler_TerrainNormalmapTexture, sampleCoords).rgb * 2 - 1));
                    half3 tangentWS = cross(GetObjectToWorldMatrix()._13_23_33, normalWS);
                    inputData.normalWS = TransformTangentToWorld(normalTS, half3x3(-tangentWS, cross(normalWS, tangentWS), normalWS));
                    half3 SH = 0;
                #else
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(IN.positionWS);
                    inputData.normalWS = IN.normal;
                    half3 SH = IN.vertexSH;
                #endif

                inputData.normalWS = NormalizeNormalPerPixel(inputData.normalWS);
                inputData.viewDirectionWS = viewDirWS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    inputData.shadowCoord = IN.shadowCoord;
                #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
                    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
                #else
                    inputData.shadowCoord = float4(0, 0, 0, 0);
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    inputData.fogCoord = InitializeInputDataFog(float4(IN.positionWS, 1.0), IN.fogFactorAndVertexLight.x);
                    inputData.vertexLighting = IN.fogFactorAndVertexLight.yzw;
                #else
                inputData.fogCoord = InitializeInputDataFog(float4(IN.positionWS, 1.0), IN.fogFactor);
                #endif

            #if defined(DYNAMICLIGHTMAP_ON)
                inputData.bakedGI = SAMPLE_GI(IN.uvMainAndLM.zw, IN.dynamicLightmapUV, SH, inputData.normalWS);
            #else
                inputData.bakedGI = SAMPLE_GI(IN.uvMainAndLM.zw, SH, inputData.normalWS);
            #endif
                inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(IN.clipPos);
                inputData.shadowMask = SAMPLE_SHADOWMASK(IN.uvMainAndLM.zw)

                #if defined(DEBUG_DISPLAY)
                #if defined(DYNAMICLIGHTMAP_ON)
                inputData.dynamicLightmapUV = IN.dynamicLightmapUV;
                #endif
                #if defined(LIGHTMAP_ON)
                inputData.staticLightmapUV = IN.uvMainAndLM.zw;
                #else
                inputData.vertexSH = SH;
                #endif
                #endif
            }

            #ifndef TERRAIN_SPLAT_BASEPASS

            void NormalMapMix(float4 uvSplat01, float4 uvSplat23, inout half4 splatControl, inout half3 mixedNormal)
            {
                #if defined(_NORMALMAP)
                    half3 nrm = half(0.0);
                    nrm += splatControl.r * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal0, sampler_Normal0, uvSplat01.xy), _NormalScale0);
                    nrm += splatControl.g * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal1, sampler_Normal0, uvSplat01.zw), _NormalScale1);
                    nrm += splatControl.b * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal2, sampler_Normal0, uvSplat23.xy), _NormalScale2);
                    nrm += splatControl.a * UnpackNormalScale(SAMPLE_TEXTURE2D(_Normal3, sampler_Normal0, uvSplat23.zw), _NormalScale3);

                    // avoid risk of NaN when normalizing.
                    #if HAS_HALF
                        nrm.z += half(0.01);
                    #else
                        nrm.z += 1e-5f;
                    #endif

                    mixedNormal = normalize(nrm.xyz);
                #endif
            }

            void SplatmapMix(float4 uvMainAndLM, float4 uvSplat01, float4 uvSplat23, inout half4 splatControl, out half weight, out half4 mixedDiffuse, out half4 defaultSmoothness, inout half3 mixedNormal)
            {
                half4 diffAlbedo[4];

                diffAlbedo[0] = SAMPLE_TEXTURE2D(_Splat0, sampler_Splat0, uvSplat01.xy);
                diffAlbedo[1] = SAMPLE_TEXTURE2D(_Splat1, sampler_Splat0, uvSplat01.zw);
                diffAlbedo[2] = SAMPLE_TEXTURE2D(_Splat2, sampler_Splat0, uvSplat23.xy);
                diffAlbedo[3] = SAMPLE_TEXTURE2D(_Splat3, sampler_Splat0, uvSplat23.zw);

                // This might be a bit of a gamble -- the assumption here is that if the diffuseMap has no
                // alpha channel, then diffAlbedo[n].a = 1.0 (and _DiffuseHasAlphaN = 0.0)
                // Prior to coming in, _SmoothnessN is actually set to max(_DiffuseHasAlphaN, _SmoothnessN)
                // This means that if we have an alpha channel, _SmoothnessN is locked to 1.0 and
                // otherwise, the true slider value is passed down and diffAlbedo[n].a == 1.0.
                defaultSmoothness = half4(diffAlbedo[0].a, diffAlbedo[1].a, diffAlbedo[2].a, diffAlbedo[3].a);
                defaultSmoothness *= half4(_Smoothness0, _Smoothness1, _Smoothness2, _Smoothness3);

            #ifndef _TERRAIN_BLEND_HEIGHT // density blending
                if(_NumLayersCount <= 4)
                {
                    // 20.0 is the number of steps in inputAlphaMask (Density mask. We decided 20 empirically)
                    half4 opacityAsDensity = saturate((half4(diffAlbedo[0].a, diffAlbedo[1].a, diffAlbedo[2].a, diffAlbedo[3].a) - (1 - splatControl)) * 20.0);
                    opacityAsDensity += 0.001h * splatControl;      // if all weights are zero, default to what the blend mask says
                    half4 useOpacityAsDensityParam = { _DiffuseRemapScale0.w, _DiffuseRemapScale1.w, _DiffuseRemapScale2.w, _DiffuseRemapScale3.w }; // 1 is off
                    splatControl = lerp(opacityAsDensity, splatControl, useOpacityAsDensityParam);
                }
            #endif

                // Now that splatControl has changed, we can compute the final weight and normalize
                weight = dot(splatControl, 1.0h);

            #ifdef TERRAIN_SPLAT_ADDPASS
                clip(weight <= 0.005h ? -1.0h : 1.0h);
            #endif

            #ifndef _TERRAIN_BASEMAP_GEN
                // Normalize weights before lighting and restore weights in final modifier functions so that the overal
                // lighting result can be correctly weighted.
                splatControl /= (weight + HALF_MIN);
            #endif

                mixedDiffuse = 0.0h;
                mixedDiffuse += diffAlbedo[0] * half4(_DiffuseRemapScale0.rgb * splatControl.rrr, 1.0h);
                mixedDiffuse += diffAlbedo[1] * half4(_DiffuseRemapScale1.rgb * splatControl.ggg, 1.0h);
                mixedDiffuse += diffAlbedo[2] * half4(_DiffuseRemapScale2.rgb * splatControl.bbb, 1.0h);
                mixedDiffuse += diffAlbedo[3] * half4(_DiffuseRemapScale3.rgb * splatControl.aaa, 1.0h);

                NormalMapMix(uvSplat01, uvSplat23, splatControl, mixedNormal);
            }

            #endif

            #ifdef _TERRAIN_BLEND_HEIGHT
            void HeightBasedSplatModify(inout half4 splatControl, in half4 masks[4])
            {
                // heights are in mask blue channel, we multiply by the splat Control weights to get combined height
                half4 splatHeight = half4(masks[0].b, masks[1].b, masks[2].b, masks[3].b) * splatControl.rgba;
                half maxHeight = max(splatHeight.r, max(splatHeight.g, max(splatHeight.b, splatHeight.a)));

                // Ensure that the transition height is not zero.
                half transition = max(_HeightTransition, 1e-5);

                // This sets the highest splat to "transition", and everything else to a lower value relative to that, clamping to zero
                // Then we clamp this to zero and normalize everything
                half4 weightedHeights = splatHeight + transition - maxHeight.xxxx;
                weightedHeights = max(0, weightedHeights);

                // We need to add an epsilon here for active layers (hence the blendMask again)
                // so that at least a layer shows up if everything's too low.
                weightedHeights = (weightedHeights + 1e-6) * splatControl;

                // Normalize (and clamp to epsilon to keep from dividing by zero)
                half sumHeight = max(dot(weightedHeights, half4(1, 1, 1, 1)), 1e-6);
                splatControl = weightedHeights / sumHeight.xxxx;
            }
            #endif

            void SplatmapFinalColor(inout half4 color, half fogCoord)
            {
                color.rgb *= color.a;

                #ifndef TERRAIN_GBUFFER // Technically we don't need fogCoord, but it is still passed from the vertex shader.

                #ifdef TERRAIN_SPLAT_ADDPASS
                    color.rgb = MixFogColor(color.rgb, half3(0,0,0), fogCoord);
                #else
                    color.rgb = MixFog(color.rgb, fogCoord);
                #endif

                #endif
            }

            ///////////////////////////////////////////////////////////////////////////////
            //                  Vertex and Fragment functions                            //
            ///////////////////////////////////////////////////////////////////////////////

            // Used in Standard Terrain shader
            Varyings SplatmapVert(Attributes v)
            {
                Varyings o = (Varyings)0;

                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TerrainInstancing(v.positionOS, v.normalOS, v.texcoord);

                VertexPositionInputs Attributes = GetVertexPositionInputs(v.positionOS.xyz);

                o.uvMainAndLM.xy = v.texcoord;
                o.uvMainAndLM.zw = v.texcoord * unity_LightmapST.xy + unity_LightmapST.zw;

                #ifndef TERRAIN_SPLAT_BASEPASS
                    o.uvSplat01.xy = TRANSFORM_TEX(v.texcoord, _Splat0);
                    o.uvSplat01.zw = TRANSFORM_TEX(v.texcoord, _Splat1);
                    o.uvSplat23.xy = TRANSFORM_TEX(v.texcoord, _Splat2);
                    o.uvSplat23.zw = TRANSFORM_TEX(v.texcoord, _Splat3);
                #endif

            #if defined(DYNAMICLIGHTMAP_ON)
                o.dynamicLightmapUV = v.texcoord * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
            #endif

                #if defined(_NORMALMAP) && !defined(ENABLE_TERRAIN_PERPIXEL_NORMAL)
                    half3 viewDirWS = GetWorldSpaceNormalizeViewDir(Attributes.positionWS);
                    float4 vertexTangent = float4(cross(float3(0, 0, 1), v.normalOS), 1.0);
                    VertexNormalInputs normalInput = GetVertexNormalInputs(v.normalOS, vertexTangent);

                    o.normal = half4(normalInput.normalWS, viewDirWS.x);
                    o.tangent = half4(normalInput.tangentWS, viewDirWS.y);
                    o.bitangent = half4(normalInput.bitangentWS, viewDirWS.z);
                #else
                    o.normal = TransformObjectToWorldNormal(v.normalOS);
                    o.vertexSH = SampleSH(o.normal);
                #endif

                half fogFactor = 0;
                #if !defined(_FOG_FRAGMENT)
                    fogFactor = ComputeFogFactor(Attributes.positionCS.z);
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    o.fogFactorAndVertexLight.x = fogFactor;
                    o.fogFactorAndVertexLight.yzw = VertexLighting(Attributes.positionWS, o.normal.xyz);
                #else
                    o.fogFactor = fogFactor;
                #endif

                o.positionWS = Attributes.positionWS;
                o.clipPos = Attributes.positionCS;

                #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
                    o.shadowCoord = GetShadowCoord(Attributes);
                #endif

                return o;
            }

            void ComputeMasks(out half4 masks[4], half4 hasMask, Varyings IN)
            {
                masks[0] = 0.5h;
                masks[1] = 0.5h;
                masks[2] = 0.5h;
                masks[3] = 0.5h;

            #ifdef _MASKMAP
                masks[0] = lerp(masks[0], SAMPLE_TEXTURE2D(_Mask0, sampler_Mask0, IN.uvSplat01.xy), hasMask.x);
                masks[1] = lerp(masks[1], SAMPLE_TEXTURE2D(_Mask1, sampler_Mask0, IN.uvSplat01.zw), hasMask.y);
                masks[2] = lerp(masks[2], SAMPLE_TEXTURE2D(_Mask2, sampler_Mask0, IN.uvSplat23.xy), hasMask.z);
                masks[3] = lerp(masks[3], SAMPLE_TEXTURE2D(_Mask3, sampler_Mask0, IN.uvSplat23.zw), hasMask.w);
            #endif

                masks[0] *= _MaskMapRemapScale0.rgba;
                masks[0] += _MaskMapRemapOffset0.rgba;
                masks[1] *= _MaskMapRemapScale1.rgba;
                masks[1] += _MaskMapRemapOffset1.rgba;
                masks[2] *= _MaskMapRemapScale2.rgba;
                masks[2] += _MaskMapRemapOffset2.rgba;
                masks[3] *= _MaskMapRemapScale3.rgba;
                masks[3] += _MaskMapRemapOffset3.rgba;
            }
            float CalculateLuminance(float3 color)
            {
                return 0.299 * color.r + 0.587 * color.g + 0.114 * color.b;
            }

            half4 CustomTerrainFragment(InputData inputData, half3 in_albedo, half in_metallic, half3 in_specular,
                half in_smoothness, half in_occlusion, half3 in_emission, half in_alpha)
            {
                SurfaceData surfaceData;

                surfaceData.albedo = in_albedo;
                surfaceData.specular = in_specular;
                surfaceData.metallic = in_metallic;
                surfaceData.smoothness = in_smoothness;
                surfaceData.normalTS = half3(0, 0, 1);
                surfaceData.emission = in_emission;
                surfaceData.occlusion = in_occlusion;
                surfaceData.alpha = in_alpha;
                surfaceData.clearCoatMask = 0;
                surfaceData.clearCoatSmoothness = 1;

                half4 shadowMask = CalculateShadowMask(inputData);
                AmbientOcclusionFactor aoFactor = CreateAmbientOcclusionFactor(inputData, surfaceData);
                Light light = GetMainLight(inputData,shadowMask,aoFactor);
                float NDotL = dot(inputData.normalWS,light.direction);
                
                float attenuation = light.distanceAttenuation * light.shadowAttenuation;
                float result = saturate(NDotL)* saturate(attenuation + _ShadowFade) * CalculateLuminance(light.color);
                result = saturate(result);
                float3 gradient_color = SAMPLE_TEXTURE2D(_gradient_map,sampler_LinearClamp,float2(result,0.5));
                float3 final = in_albedo * gradient_color;
                return float4(final,1);
            }
            

            // Used in Standard Terrain shader
            #ifdef TERRAIN_GBUFFER
            FragmentOutput SplatmapFragment(Varyings IN)
            #else
            void SplatmapFragment(
                Varyings IN
                , out half4 outColor : SV_Target0
            #ifdef _WRITE_RENDERING_LAYERS
                , out float4 outRenderingLayers : SV_Target1
            #endif
                )
            #endif
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(IN);
            #ifdef _ALPHATEST_ON
                ClipHoles(IN.uvMainAndLM.xy);
            #endif

                half3 normalTS = half3(0.0h, 0.0h, 1.0h);
            #ifdef TERRAIN_SPLAT_BASEPASS
                half3 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uvMainAndLM.xy).rgb;
                half smoothness = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uvMainAndLM.xy).a;
                half metallic = SAMPLE_TEXTURE2D(_MetallicTex, sampler_MetallicTex, IN.uvMainAndLM.xy).r;
                half alpha = 1;
                half occlusion = 1;
            #else

                half4 hasMask = half4(_LayerHasMask0, _LayerHasMask1, _LayerHasMask2, _LayerHasMask3);
                half4 masks[4];
                ComputeMasks(masks, hasMask, IN);

                float2 splatUV = (IN.uvMainAndLM.xy * (_Control_TexelSize.zw - 1.0f) + 0.5f) * _Control_TexelSize.xy;
                half4 splatControl = SAMPLE_TEXTURE2D(_Control, sampler_Control, splatUV);

                half alpha = dot(splatControl, 1.0h);
            #ifdef _TERRAIN_BLEND_HEIGHT
                // disable Height Based blend when there are more than 4 layers (multi-pass breaks the normalization)
                if (_NumLayersCount <= 4)
                    HeightBasedSplatModify(splatControl, masks);
            #endif

                half weight;
                half4 mixedDiffuse;
                half4 defaultSmoothness;
                SplatmapMix(IN.uvMainAndLM, IN.uvSplat01, IN.uvSplat23, splatControl, weight, mixedDiffuse, defaultSmoothness, normalTS);
                half3 albedo = mixedDiffuse.rgb;

                half4 defaultMetallic = half4(_Metallic0, _Metallic1, _Metallic2, _Metallic3);
                half4 defaultOcclusion = half4(_MaskMapRemapScale0.g, _MaskMapRemapScale1.g, _MaskMapRemapScale2.g, _MaskMapRemapScale3.g) +
                                        half4(_MaskMapRemapOffset0.g, _MaskMapRemapOffset1.g, _MaskMapRemapOffset2.g, _MaskMapRemapOffset3.g);

                half4 maskSmoothness = half4(masks[0].a, masks[1].a, masks[2].a, masks[3].a);
                defaultSmoothness = lerp(defaultSmoothness, maskSmoothness, hasMask);
                half smoothness = dot(splatControl, defaultSmoothness);

                half4 maskMetallic = half4(masks[0].r, masks[1].r, masks[2].r, masks[3].r);
                defaultMetallic = lerp(defaultMetallic, maskMetallic, hasMask);
                half metallic = dot(splatControl, defaultMetallic);

                half4 maskOcclusion = half4(masks[0].g, masks[1].g, masks[2].g, masks[3].g);
                defaultOcclusion = lerp(defaultOcclusion, maskOcclusion, hasMask);
                half occlusion = dot(splatControl, defaultOcclusion);
            #endif

                InputData inputData;
                InitializeInputData(IN, normalTS, inputData);
                SETUP_DEBUG_TEXTURE_DATA(inputData, IN.uvMainAndLM.xy, _BaseMap);

            #if defined(_DBUFFER)
                half3 specular = half3(0.0h, 0.0h, 0.0h);
                ApplyDecal(IN.clipPos,
                    albedo,
                    specular,
                    inputData.normalWS,
                    metallic,
                    occlusion,
                    smoothness);
            #endif
                half4 color = CustomTerrainFragment(inputData, albedo, metallic, /* specular */ half3(0.0h, 0.0h, 0.0h), smoothness, occlusion, /* emission */ half3(0, 0, 0), alpha);
                
                
                SplatmapFinalColor(color, inputData.fogCoord);
                outColor = half4(color.rgb, 1.0h);

            #ifdef _WRITE_RENDERING_LAYERS
                uint renderingLayers = GetMeshRenderingLayer();
                outRenderingLayers = float4(EncodeMeshRenderingLayer(renderingLayers), 0, 0, 0);
            #endif
            }

            // Shadow pass

            // Shadow Casting Light geometric parameters. These variables are used when applying the shadow Normal Bias and are set by UnityEngine.Rendering.Universal.ShadowUtils.SetupShadowCasterConstantBuffer in com.unity.render-pipelines.universal/Runtime/ShadowUtils.cs
            // For Directional lights, _LightDirection is used when applying shadow Normal Bias.
            // For Spot lights and Point lights, _LightPosition is used to compute the actual light direction because it is different at each shadow caster geometry vertex.
            float3 _LightDirection;
            float3 _LightPosition;

            struct AttributesLean
            {
                float4 position     : POSITION;
                float3 normalOS       : NORMAL;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct VaryingsLean
            {
                float4 clipPos      : SV_POSITION;
                float2 texcoord     : TEXCOORD0;
                UNITY_VERTEX_OUTPUT_STEREO
            };

            VaryingsLean ShadowPassVertex(AttributesLean v)
            {
                VaryingsLean o = (VaryingsLean)0;
                UNITY_SETUP_INSTANCE_ID(v);
                TerrainInstancing(v.position, v.normalOS, v.texcoord);

                float3 positionWS = TransformObjectToWorld(v.position.xyz);
                float3 normalWS = TransformObjectToWorldNormal(v.normalOS);

            #if _CASTING_PUNCTUAL_LIGHT_SHADOW
                float3 lightDirectionWS = normalize(_LightPosition - positionWS);
            #else
                float3 lightDirectionWS = _LightDirection;
            #endif

                float4 clipPos = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));

            #if UNITY_REVERSED_Z
                clipPos.z = min(clipPos.z, UNITY_NEAR_CLIP_VALUE);
            #else
                clipPos.z = max(clipPos.z, UNITY_NEAR_CLIP_VALUE);
            #endif

                o.clipPos = clipPos;

                o.texcoord = v.texcoord;

                return o;
            }

            half4 ShadowPassFragment(VaryingsLean IN) : SV_TARGET
            {
            #ifdef _ALPHATEST_ON
                ClipHoles(IN.texcoord);
            #endif
                return 0;
            }

            // Depth pass

            VaryingsLean DepthOnlyVertex(AttributesLean v)
            {
                VaryingsLean o = (VaryingsLean)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
                TerrainInstancing(v.position, v.normalOS);
                o.clipPos = TransformObjectToHClip(v.position.xyz);
                o.texcoord = v.texcoord;
                return o;
            }

            half4 DepthOnlyFragment(VaryingsLean IN) : SV_TARGET
            {
            #ifdef _ALPHATEST_ON
                ClipHoles(IN.texcoord);
            #endif
            #ifdef SCENESELECTIONPASS
                // We use depth prepass for scene selection in the editor, this code allow to output the outline correctly
                return half4(_ObjectId, _PassValue, 1.0, 1.0);
            #endif
                return IN.clipPos.z;
            }

            #endif

            
            ENDHLSL
        }

        Pass
        {
            Name "ShadowCaster"
            Tags{"LightMode" = "ShadowCaster"}

            ZWrite On
            ColorMask 0

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex ShadowPassVertex
            #pragma fragment ShadowPassFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            // -------------------------------------
            // Universal Pipeline keywords

            // This is used during shadow map generation to differentiate between directional and punctual light shadows, as they use different formulas to apply Normal Bias
            #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "GBuffer"
            Tags{"LightMode" = "UniversalGBuffer"}

            HLSLPROGRAM
            #pragma target 4.5

            // Deferred Rendering Path does not support the OpenGL-based graphics API:
            // Desktop OpenGL, OpenGL ES 3.0, WebGL 2.0.
            #pragma exclude_renderers gles3 glcore

            #pragma vertex SplatmapVert
            #pragma fragment SplatmapFragment

            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            // -------------------------------------
            // Universal Pipeline keywords
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            //#pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            //#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
            #pragma multi_compile _ _MIXED_LIGHTING_SUBTRACTIVE
            #pragma multi_compile_fragment _ _DBUFFER_MRT1 _DBUFFER_MRT2 _DBUFFER_MRT3
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            // -------------------------------------
            // Unity defined keywords
            #pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
            #pragma multi_compile _ SHADOWS_SHADOWMASK
            #pragma multi_compile _ DIRLIGHTMAP_COMBINED
            #pragma multi_compile _ LIGHTMAP_ON
            #pragma multi_compile _ DYNAMICLIGHTMAP_ON
            #pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT
            #pragma multi_compile_fragment _ _RENDER_PASS_ENABLED

            //#pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #pragma shader_feature_local _TERRAIN_BLEND_HEIGHT
            #pragma shader_feature_local _NORMALMAP
            #pragma shader_feature_local _MASKMAP
            // Sample normal in pixel shader when doing instancing
            #pragma shader_feature_local _TERRAIN_INSTANCED_PERPIXEL_NORMAL
            #define TERRAIN_GBUFFER 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "DepthOnly"
            Tags{"LightMode" = "DepthOnly"}

            ZWrite On
            ColorMask R

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        // This pass is used when drawing to a _CameraNormalsTexture texture
        Pass
        {
            Name "DepthNormals"
            Tags{"LightMode" = "DepthNormals"}

            ZWrite On

            HLSLPROGRAM
            #pragma target 2.0
            #pragma vertex DepthNormalOnlyVertex
            #pragma fragment DepthNormalOnlyFragment

            #pragma shader_feature_local _NORMALMAP
            #include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/RenderingLayers.hlsl"

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitDepthNormalsPass.hlsl"
            ENDHLSL
        }

        Pass
        {
            Name "SceneSelectionPass"
            Tags { "LightMode" = "SceneSelectionPass" }

            HLSLPROGRAM
            #pragma target 2.0

            #pragma vertex DepthOnlyVertex
            #pragma fragment DepthOnlyFragment

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap

            #define SCENESELECTIONPASS
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitPasses.hlsl"
            ENDHLSL
        }

        // This pass it not used during regular rendering, only for lightmap baking.
        Pass
        {
            Name "Meta"
            Tags{"LightMode" = "Meta"}

            Cull Off

            HLSLPROGRAM
            #pragma vertex TerrainVertexMeta
            #pragma fragment TerrainFragmentMeta

            #pragma multi_compile_instancing
            #pragma instancing_options assumeuniformscaling nomatrices nolightprobe nolightmap
            #pragma shader_feature EDITOR_VISUALIZATION
            #define _METALLICSPECGLOSSMAP 1
            #define _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A 1

            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/Terrain/TerrainLitMetaPass.hlsl"

            ENDHLSL
        }

        UsePass "Hidden/Nature/Terrain/Utilities/PICKING"
    }
    Dependency "AddPassShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Add Pass)"
    Dependency "BaseMapShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Base Pass)"
    Dependency "BaseMapGenShader" = "Hidden/Universal Render Pipeline/Terrain/Lit (Basemap Gen)"
    

    Fallback "Hidden/Universal Render Pipeline/FallbackError"
}
