using System;
using System.Collections;
using System.Collections.Generic;
using UnityEditor.TerrainTools;
using UnityEngine;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering;
using RTHandle = UnityEngine.Rendering.RTHandle;
using UnityEditor;
using UnityEngine.Experimental.Rendering;

[ExecuteAlways]
public class TerrainColor : MonoBehaviour
{
    public Material terrain_mt;
    public Gradient color_ramp;

    private Texture2D gradient_color;

    
    void Update()
    {
        if (terrain_mt != null && gradient_color!=null)
        {
            terrain_mt.SetTexture("_gradient_map",gradient_color);
        }
    }
    
    private void OnValidate()
    {
        Generate_Ramp_Texture();
    }
    
    private void OnEnable()
    {
        Generate_Ramp_Texture();
    }
    
    void Generate_Ramp_Texture()
    {
        if (gradient_color == null)
        {
            gradient_color = new Texture2D(128, 2, GraphicsFormat.B8G8R8A8_SRGB, TextureCreationFlags.None);
        }

        var cols = new Color[256];
        for (int i = 0; i < 128; i++)
        {
            cols[i] = color_ramp.Evaluate(i / 128f);
            cols[i+128] = color_ramp.Evaluate(i / 128f);
        }

        gradient_color.SetPixels(cols);
        gradient_color.Apply();
    }
}
