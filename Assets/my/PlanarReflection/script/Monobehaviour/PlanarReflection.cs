using System;
using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEditor;

[ExecuteAlways]
public class PlanarReflection : MonoBehaviour
{
    public int reflection_texture_width = 1920;
    public int reflection_texture_height = 1080;
    public LayerMask culling_mask = -1;
    [Range(-1,1)]
    public float reflect_offset = 1f;
    
    private GameObject _target_plane;
    private Camera _reflect_cam;
    private RTHandle _reflect_rt;
    private const string _reflect_rt_name = "planar_reflection_rt";

    private void OnEnable()
    {
        RenderPipelineManager.beginCameraRendering += Run_Reflection;
    }

    private void OnDisable()
    {
        Release();
    }

    private void OnDestroy()
    {
        Release();
    }

    private void Run_Reflection(ScriptableRenderContext context, Camera camera)
    {   
        if (camera.cameraType == CameraType.Reflection || camera.cameraType == CameraType.Preview)
            return;
        
        
        Setup(camera);
        Capture_Refecltion_Texture(context,camera);
    }


    private void Setup(Camera src_cam)
    {
        int _reflect_rt_width = reflection_texture_width;
        int _reflect_rt_height = reflection_texture_height;
        RenderTextureFormat _reflect_rt_format = RenderTextureFormat.ARGB32;
        RenderTextureDescriptor descriptor = new RenderTextureDescriptor(_reflect_rt_width,_reflect_rt_height,_reflect_rt_format);
        descriptor.msaaSamples = 1;
        descriptor.depthBufferBits = 0;
        RenderingUtils.ReAllocateIfNeeded(ref _reflect_rt, descriptor, name: _reflect_rt_name);
        _target_plane = gameObject;
        if (!_reflect_cam) _reflect_cam = Create_Reflection_Camera();
        Update_Reflection_Camera(src_cam);
    }

    
    private void Release()
    {
        RenderPipelineManager.beginCameraRendering -= Run_Reflection;
        if (_reflect_cam)
        {
            _reflect_cam.targetTexture = null;
            GameObject.DestroyImmediate(_reflect_cam.gameObject);
        }
        
        _reflect_rt?.Release();
        _reflect_rt = null;
    }
    
    /// <summary>
    /// ------------------------------------------------------------------------------------FUNCTION
    /// </summary>
    /// <returns></returns>
    ///
    private void Capture_Refecltion_Texture(ScriptableRenderContext context,Camera camera)
    {
        //反射矩阵
        Matrix4x4 reflection_matrix = Calculate_Reflection_Matrix();
        _reflect_cam.worldToCameraMatrix = camera.worldToCameraMatrix * reflection_matrix;
        
        //斜截视锥体
        Vector4 VS_plane = Calculate_ViewSpace_Plane();
        //Matrix4x4 Oblique_mat = Calculate_Oblique_Matrix(camera,VS_plane); //自己的api，为啥我的有问题？？
        Matrix4x4 Oblique_mat = _reflect_cam.CalculateObliqueMatrix(VS_plane); // 官方api
        _reflect_cam.projectionMatrix = Oblique_mat;
        
        Reflect_Camera_Pos(); //重要
        PlanarReflectionRenderSetting renderSetting = new PlanarReflectionRenderSetting();
        renderSetting.Set(); //重要
        UniversalRenderPipeline.RenderSingleCamera(context, _reflect_cam);
        renderSetting.Restore();
        Shader.SetGlobalTexture("_Planar_Reflection_Texture",_reflect_rt);
    }

    Vector4 Calculate_ViewSpace_Plane()
    {
        Vector3 WS_plane_pos = _target_plane.transform.position + _target_plane.transform.up * reflect_offset;
        Vector3 WS_plane_normal = _target_plane.transform.up;
        Matrix4x4 WS_To_VS_mat = _reflect_cam.worldToCameraMatrix;
        Vector3 VS_plane_pos = WS_To_VS_mat.MultiplyPoint(WS_plane_pos);
        Vector3 VS_plane_normal = WS_To_VS_mat.MultiplyVector(WS_plane_normal);
        return new Vector4(VS_plane_normal.x, VS_plane_normal.y, VS_plane_normal.z,
            -Vector3.Dot(VS_plane_pos, VS_plane_normal));
    }

    Matrix4x4 Calculate_Oblique_Matrix(Camera camera,Vector4 VS_plane)
    {
        Vector4 CS_Q = new Vector4(Mathf.Sign(VS_plane.x), Mathf.Sign(VS_plane.y), 1f, 1f);
        Vector4 VS_Q = camera.projectionMatrix.inverse.MultiplyPoint(CS_Q);

        Vector4 Oblique_VS_plnae = VS_plane * 2.0f / Vector4.Dot(VS_Q, VS_plane);
        Vector4 M3 = Oblique_VS_plnae - camera.projectionMatrix.GetRow(3);
        
        if(M3.w < 0.00001f & M3.w >= 0.0f)
        {
            M3.w = 0.00001f;
        }else if(M3.w > -0.00001f & M3.w < 0.0f){
            M3.w = -0.00001f;
        }

        Matrix4x4 Oblique_Mat = camera.projectionMatrix;
        Oblique_Mat.SetRow(2,M3);
        return Oblique_Mat;
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

    private void Update_Reflection_Camera(Camera src_cam)
    {
        if(!src_cam)return;
        
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
        _reflect_cam.cullingMask = culling_mask; // 重要
        _reflect_cam.targetTexture = _reflect_rt;
    }
    
    void Reflect_Camera_Pos()
    {
        Vector3 camPosPS = _target_plane.transform.worldToLocalMatrix.MultiplyPoint(_reflect_cam.gameObject.transform.position);
        Vector3 reflectCamPosPS = Vector3.Scale(camPosPS, new Vector3(1, -1, 1));  // 反射相机平面空间
        Vector3 reflectCamPosWS = _target_plane.transform.localToWorldMatrix.MultiplyPoint(reflectCamPosPS);  // 将反射相机转换到世界空间
        _reflect_cam.gameObject.transform.position = reflectCamPosWS;
    }

    Matrix4x4 Calculate_Reflection_Matrix()
    {
        float xn = _target_plane.transform.up.x;
        float yn = _target_plane.transform.up.y;
        float zn = _target_plane.transform.up.z;
        Vector3 pos = _target_plane.transform.position + _target_plane.transform.up * reflect_offset;
        float d = -Vector3.Dot(pos,_target_plane.transform.up);
        Matrix4x4 output = Matrix4x4.identity;
        output.m00 = 1.0f - 2.0f * xn * xn;
        output.m01 = -2.0f * yn * xn;
        output.m02 = -2.0f * zn * xn;
        output.m03 = -2.0f * xn * d;
        
        output.m10 = -2.0f * yn * xn;
        output.m11 = 1.0f - 2.0f * yn * yn;
        output.m12 = -2.0f * zn * yn;
        output.m13 = -2.0f * yn * d;
        
        output.m20 = -2.0f * zn * xn;
        output.m21 = -2.0f * zn * yn;
        output.m22 = 1.0f - 2.0f * zn * zn;
        output.m23 = -2.0f * zn * d;
        
        output.m30 = 0.0f;
        output.m31 = 0.0f;
        output.m32 = 0.0f;
        output.m33 = 1.0f;
        return output;
    }
    
     class PlanarReflectionRenderSetting {
        private readonly bool _fog;
        private bool _invertCulling;

        public PlanarReflectionRenderSetting() {
            _fog = RenderSettings.fog;
        }

        public void Set() {
            _invertCulling = GL.invertCulling;
            GL.invertCulling = !_invertCulling;  // 因为镜像后绕序会反，将剔除反向
            RenderSettings.fog = false; // disable fog for now as it's incorrect with projection
        }

        public void Restore() {
            GL.invertCulling = _invertCulling;
            RenderSettings.fog = _fog;
        }
    }

    public RTHandle test()
    {
        return _reflect_rt;
    }
}

[CustomEditor(typeof(PlanarReflection))]
public class TextureDisplayEditor : Editor
{
    public override void OnInspectorGUI()
    {
        base.OnInspectorGUI();
        PlanarReflection m = target as PlanarReflection;
        RTHandle tst = m.test();

        if (tst != null)
        {
            GUILayout.Label(tst); // 显示Texture2D
        }
        else
        {
            GUILayout.Label("No Texture assigned.");
        }
    }
}
