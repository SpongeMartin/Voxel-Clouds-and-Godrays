using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class computeTest : MonoBehaviour
{
    private int noisePass;
    public ComputeShader computeShader;
    public RenderTexture renderTexture;

    public float scale = 0.1f;
    public Vector2 offset = Vector2.zero;
    // Start is called before the first frame update

    private void OnRenderImage(RenderTexture src, RenderTexture dest){
        if (renderTexture == null){
            renderTexture = new RenderTexture(256,256,24);
            renderTexture.enableRandomWrite = true;
            renderTexture.Create();
        }
        computeShader.SetFloat("scale", scale);
        computeShader.SetVector("offset", offset);
        computeShader.SetTexture(0,"Result",renderTexture);
        computeShader.SetFloat("Resolution",renderTexture.width);
        computeShader.Dispatch(noisePass,renderTexture.width/8, renderTexture.height/8,1);
        
        Graphics.Blit(renderTexture,dest);
    }

    void Start()
    {
        renderTexture = new RenderTexture(256,256,24);
        renderTexture.enableRandomWrite = true;
        renderTexture.Create();
        noisePass = computeShader.FindKernel("CS_Noise");
        computeShader.SetFloat("scale", scale);
        computeShader.SetVector("offset", offset);
        computeShader.SetTexture(0,"Result",renderTexture);
        computeShader.Dispatch(noisePass,renderTexture.width/8, renderTexture.height/8,1);

    }

}
