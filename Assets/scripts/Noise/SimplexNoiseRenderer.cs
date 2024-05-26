using UnityEngine;

public class SimplexNoiseRenderer : MonoBehaviour
{
    public ComputeShader simplexNoiseComputeShader;
    public Material displayMaterial;

    private RenderTexture renderTexture;
    public int resolution = 256;
    public float scale = 1.0f;
    public Vector2 offset = Vector2.zero;

    void Start()
    {
        renderTexture = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGB32);
        renderTexture.enableRandomWrite = true;
        renderTexture.Create();
        GenerateSimplexNoise();
    }

    void GenerateSimplexNoise()
    {
        int kernelHandle = simplexNoiseComputeShader.FindKernel("CSMain");
        simplexNoiseComputeShader.SetInt("_Resolution", resolution);
        simplexNoiseComputeShader.SetFloat("_Scale", scale);
        simplexNoiseComputeShader.SetVector("_Offset", offset);
        simplexNoiseComputeShader.SetTexture(kernelHandle, "Result", renderTexture);

        int threadGroupsX = Mathf.CeilToInt(resolution / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(resolution / 8.0f);
        simplexNoiseComputeShader.Dispatch(kernelHandle, threadGroupsX, threadGroupsY, 1);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        GenerateSimplexNoise();
        Graphics.Blit(renderTexture, dest);
    }

    void OnDestroy()
    {
        if (renderTexture != null)
        {
            renderTexture.Release();
            Destroy(renderTexture);
        }
    }

    public RenderTexture GetRenderTexture(){
        return renderTexture;
    }
}
