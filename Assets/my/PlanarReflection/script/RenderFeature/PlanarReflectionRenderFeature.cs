using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Experimental.Rendering;
using UnityEngine.Serialization;
using Unity.Mathematics;

public class PlanarReflectionRenderFeature : ScriptableRendererFeature
{
    
    private PlanarReflectionRenderPass custom_Pass;

    public override void Create()
    {
        custom_Pass?.Release();
        custom_Pass = new PlanarReflectionRenderPass(RenderPassEvent.AfterRenderingPostProcessing);
        custom_Pass.PrepareData();
        
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if(custom_Pass.IsReady())renderer.EnqueuePass(custom_Pass);
    }

    private void OnDisable()
    {
        custom_Pass.Release();
    }
}
