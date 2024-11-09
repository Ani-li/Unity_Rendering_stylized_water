using System.Collections;
using System.Collections.Generic;
using System;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEditorInternal;

public class PlanarReflectionRenderPass : ScriptableRenderPass
{
    private GameObject _target_plane;

    private const string _target_plane_tag = "planar_reflect_plane";
    private Camera _reflect_cam;
    private RTHandle _reflect_rt;
    private const string _reflect_rt_name = "planar_reflection_rt";
    private RTHandle _test_rt;
    
    public PlanarReflectionRenderPass(RenderPassEvent renderPassEvent)
    {
        this.renderPassEvent = renderPassEvent;
    }

    public override void OnCameraSetup(CommandBuffer cmd, ref RenderingData renderingData)
    {
        var descriptor = renderingData.cameraData.cameraTargetDescriptor;
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _reflect_rt, descriptor, name: _reflect_rt_name);
        RenderingUtils.ReAllocateIfNeeded(ref _test_rt, descriptor, name: "test_rt");
        Find_Reflection_Plane();
        if (!_reflect_cam) _reflect_cam = Create_Reflection_Camera();
        Update_Reflection_Camera(renderingData);
    }

    public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
    {
        ///UniversalRenderPipeline.RenderSingleCamera(context, _reflect_cam);
        var cmd = CommandBufferPool.Get();
        context.ExecuteCommandBuffer(cmd);
        cmd.Clear();

        using (new ProfilingScope(cmd, new ProfilingSampler("Custom Planar Reflection")))
        {
            Blitter.BlitCameraTexture(cmd,_reflect_rt,_test_rt);
        }
        
        context.ExecuteCommandBuffer(cmd);
        CommandBufferPool.Release(cmd);
    }

    public void PrepareData()
    {
        
    }

    public bool IsReady()
    {
        return true;
    }

    public void Release()
    {
        if (_reflect_cam)
        {
            _reflect_cam.targetTexture = null;
            GameObject.DestroyImmediate(_reflect_cam.gameObject);
        }
        
        _reflect_rt?.Release();
        _reflect_rt = null;
    }

    private void Find_Reflection_Plane()
    {
        if (IsTagDefined(_target_plane_tag) == false)
        {
            Debug.LogWarning("Please degined tag :" + _target_plane_tag);
            return;
        }
        GameObject[] objs = GameObject.FindGameObjectsWithTag(_target_plane_tag);
        if (objs.Length == 0)
        {
            Debug.LogWarning("no object with tag "+ _target_plane_tag);
            return;
        }

        if (objs.Length > 1)
        {
            Debug.LogWarning("only one plane is allowed exist!");
            return;
        }

        _target_plane = objs[0];

    }

    private Camera Create_Reflection_Camera()
    {
        var go = new GameObject("planar_camera");
        var cam = go.AddComponent<Camera>();

        var additionalCamData = cam.GetUniversalAdditionalCameraData();
        additionalCamData.renderShadows = false;
        additionalCamData.requiresColorOption = CameraOverrideOption.Off;
        additionalCamData.requiresDepthOption = CameraOverrideOption.Off;

        go.hideFlags = HideFlags.HideAndDontSave;
        cam.enabled = false;
        return cam;
    }

    private void Update_Reflection_Camera(RenderingData renderingData)
    {
        if(!renderingData.cameraData.camera)return;
        Camera src_cam = renderingData.cameraData.camera;

        _reflect_cam.gameObject.transform.SetPositionAndRotation(src_cam.transform.position,src_cam.transform.rotation);

        _reflect_cam.aspect = src_cam.aspect;
        _reflect_cam.cameraType = src_cam.cameraType;
        _reflect_cam.clearFlags = src_cam.clearFlags;
        _reflect_cam.fieldOfView = src_cam.fieldOfView;
        _reflect_cam.depth = src_cam.depth;
        _reflect_cam.farClipPlane = src_cam.farClipPlane;
        _reflect_cam.nearClipPlane = src_cam.nearClipPlane;
        _reflect_cam.focalLength = src_cam.focalLength;
        _reflect_cam.useOcclusionCulling = false;
        _reflect_cam.targetTexture = _reflect_rt;
        
    }
    
    bool IsTagDefined(string tag)
    {
        string[] tags = InternalEditorUtility.tags;
        foreach (string t in tags)
        {
            if (t == tag)
            {
                return true;
            }
        }
        return false;
    }
    
    
}
