using UnityEngine;

public class WorleyNoiseRenderer : MonoBehaviour
{
    public ComputeShader worleyNoiseComputeShader;
    public Material displayMaterial;
    public int textureWidth = 128;
    public int textureHeight = 128;
    public int textureDepth = 128;
    public float scale = 10.0f;

    public float lfreq = 1.0f;
    public float mfreq = 2.0f;
    public float hfreq = 3.0f;
    public float pwfreq = 2.0f;

    // Previous values for checking changes
    private float prevScale;
    private float prevLowFreq;
    private float prevMedFreq;
    private float prevHighFreq;
    private float prevPerlinWorleyFreq;
    [SerializeField]
    public RenderTexture worleyRenderTexture;

    void Start()
    {
        worleyRenderTexture = new RenderTexture(textureWidth, textureHeight, 0, RenderTextureFormat.ARGBFloat);
        worleyRenderTexture.volumeDepth = textureDepth;
        worleyRenderTexture.enableRandomWrite = true;
        worleyRenderTexture.dimension = UnityEngine.Rendering.TextureDimension.Tex3D;

        GenerateWorleyNoise();
    }

    public void GenerateWorleyNoise()
    {
        int kernelHandle = worleyNoiseComputeShader.FindKernel("CSMain");
        worleyNoiseComputeShader.SetInt("_Width", textureWidth);
        worleyNoiseComputeShader.SetInt("_Height", textureHeight);
        worleyNoiseComputeShader.SetInt("_Depth", textureDepth);
        worleyNoiseComputeShader.SetFloat("_Scale", scale);
        worleyNoiseComputeShader.SetFloat("_LowFreq",lfreq);
        worleyNoiseComputeShader.SetFloat("_MedFreq",mfreq);
        worleyNoiseComputeShader.SetFloat("_HighFreq",hfreq);
        worleyNoiseComputeShader.SetFloat("_PerlinWorleyFreq",pwfreq);

        worleyNoiseComputeShader.SetTexture(kernelHandle, "Result", worleyRenderTexture);

        int threadGroupsX = Mathf.CeilToInt(textureWidth / 8.0f);
        int threadGroupsY = Mathf.CeilToInt(textureHeight / 8.0f);
        int threadGroupsZ = Mathf.CeilToInt(textureDepth / 8.0f);
        worleyNoiseComputeShader.Dispatch(kernelHandle, threadGroupsX, threadGroupsY,threadGroupsZ);
    }

    void OnRenderImage(RenderTexture src, RenderTexture dest)
    {
        if (ParametersChanged())
        {
            GenerateWorleyNoise();
        }
        //displayMaterial.SetTexture("_MainTex", renderTexture);
        //displayMaterial.SetFloat("_Scale", scale);
    }

    private bool ParametersChanged()
    {
        if (scale != prevScale ||
            lfreq != prevLowFreq ||
            mfreq != prevMedFreq ||
            hfreq != prevHighFreq ||
            pwfreq != prevPerlinWorleyFreq)
        {
            prevScale = scale;
            prevLowFreq = lfreq;
            prevMedFreq = mfreq;
            prevHighFreq = hfreq;
            prevPerlinWorleyFreq = pwfreq;
            return true;
        }
        return false;
    }

    void OnDestroy()
    {
        if (worleyRenderTexture != null)
        {
            worleyRenderTexture.Release();
            Destroy(worleyRenderTexture);
        }
    }
}
