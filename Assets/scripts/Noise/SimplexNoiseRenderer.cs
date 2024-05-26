using UnityEngine;

public class SimplexNoiseRenderer : MonoBehaviour
{
    public ComputeShader simplexNoiseComputeShader;
    public Material displayMaterial;
    [SerializeField]
    public RenderTexture simplexRenderTexture;
    public int resolution = 128;
    private int prevResolution;
    public float scale = 1.0f;
    private float prevScale;
    public Vector2 offset = Vector2.zero;
    private Vector2 prevOffset;
    public Vector2 minMax = new Vector2 (0, 1);

    void Start()
    {
        CreateTexture();
        GenerateSimplexNoise();
    }

    //public void UpdateSimplex(){
    //    GenerateSimplexNoise();
    //}

    public void GenerateSimplexNoise()
    {
        CreateTexture();
        int kernelHandle = simplexNoiseComputeShader.FindKernel("CSMain");
        simplexNoiseComputeShader.SetInt("_Resolution", resolution);
        simplexNoiseComputeShader.SetFloat("_Scale", scale);
        simplexNoiseComputeShader.SetVector ("_MinMax", minMax);
        simplexNoiseComputeShader.SetTexture(kernelHandle, "Result", simplexRenderTexture);

        int threadGroupsX = Mathf.CeilToInt(resolution / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(resolution / 8.0f);
        simplexNoiseComputeShader.Dispatch(kernelHandle, threadGroupsX, threadGroupsY, 1);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (ParametersChanged()){
            GenerateSimplexNoise();
        }
        //Graphics.Blit(renderTexture, dest);
    }

    private bool ParametersChanged()
    {
        if (resolution != prevResolution || scale != prevScale || offset != prevOffset){
            prevScale = scale;
            prevResolution = resolution;
            prevOffset = offset;
            return true;
        }
        return false;
    }

    void CreateTexture(){
        if (simplexRenderTexture != null) {
            simplexRenderTexture.Release();
        }
        simplexRenderTexture = new RenderTexture(resolution, resolution, 0, RenderTextureFormat.ARGBFloat);
        simplexRenderTexture.enableRandomWrite = true;
        simplexRenderTexture.volumeDepth = resolution;
        simplexRenderTexture.Create();
        simplexRenderTexture.wrapMode = TextureWrapMode.Clamp;
        simplexRenderTexture.filterMode = FilterMode.Bilinear;
    }

    void OnDestroy()
    {
        if (simplexRenderTexture != null)
        {
            simplexRenderTexture.Release();
            Destroy(simplexRenderTexture);
        }
    }

}
