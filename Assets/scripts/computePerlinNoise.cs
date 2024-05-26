using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class computePerlinNoise : MonoBehaviour
{
    public int textureSize = 32;
    public float scale = 20.0f;
    private ComputeShader perlinGenerator;
    public Material noiseMaterial; 

    void OnEnable()
    {
        perlinGenerator = (ComputeShader)Resources.Load("perlinNoiseGenerator");
        RenderTexture perlinTexture = GeneratePerlinNoise3DTexture(textureSize, scale);
        noiseMaterial.SetTexture("_PerlinTex",perlinTexture);
        //Shader.SetGlobalTexture("_PerlinNoise3D", perlinTexture);
    }

    void onRenderImage(RenderTexture source, RenderTexture destination){

    }

    RenderTexture GeneratePerlinNoise3DTexture(int size, float scale)
    {
        RenderTexture noiseTex = new RenderTexture(128, 128, 0, RenderTextureFormat.RHalf, RenderTextureReadWrite.Linear);
        noiseTex.enableRandomWrite = true;
        noiseTex.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;
        noiseTex.volumeDepth = 128;
        noiseTex.Create();
        Debug.Log(perlinGenerator);

        perlinGenerator.SetTexture(0, "Result", noiseTex); 
        perlinGenerator.SetInt("_TextureSize", 128);
        perlinGenerator.SetInt("_Scale", 1);

        // 128 / 8
        perlinGenerator.Dispatch(0, 16, 16, 16);

        return noiseTex;
    }
}