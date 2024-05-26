using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CloudController : MonoBehaviour
{
    public Shader shader;
    public Transform container;
    public int numSteps = 10;
    public float cloudScale = 1.0f;

    public float densityMultiplier = 1.0f;
    [Range (0, 1)]
    public float densityThreshold = 1.0f;

    public SimplexNoiseRenderer simplexNoiseRenderer;
    public WorleyNoiseRenderer worleyNoiseRenderer;

    public Vector3 offset = new Vector3(0,0,0);

    Material material;

    private void onRenderImage(RenderTexture src,RenderTexture dest){
        if(material == null){
            material = new Material(shader);
        }
        material.SetVector("_BoundsMin", container.position - container.localScale / 2);
        material.SetVector("_BoundsMax", container.position + container.localScale / 2);
        material.SetVector("_CloudOffset", offset);
        material.SetFloat("_CloudScale", cloudScale);
        material.SetFloat("_DensityThreshold", densityThreshold);
        material.SetFloat("_DensityMultiplier", densityMultiplier);
        material.SetInt("_NumSteps", numSteps);

        material.SetTexture("_SimplexNoise", simplexNoiseRenderer.GetRenderTexture());
        material.SetTexture("_WorleyFBM", worleyNoiseRenderer.GetRenderTexture());

        Graphics.Blit(src,dest,material);
    }

}
