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
    public Vector3 offset = new Vector3(0,0,0);
    public RenderTexture simp;
    public RenderTexture worley;

    public Material material;

    void Awake(){
        var weathermap = FindObjectOfType<SimplexNoiseRenderer>();
        /*if (Application.isPlaying) {
            weathermap.GenerateSimplexNoise();
        }*/
    }

    private void OnRenderImage(RenderTexture src,RenderTexture dest){
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
        var weathermap = FindObjectOfType<SimplexNoiseRenderer>();
        weathermap.GenerateSimplexNoise();

        material.SetTexture("_SimplexNoise", weathermap.simplexRenderTexture);
        simp = weathermap.simplexRenderTexture;
        var noise = FindObjectOfType<WorleyNoiseRenderer>();
        noise.GenerateWorleyNoise();
        material.SetTexture("_WorleyFBM", noise.worleyRenderTexture);

        worley = noise.worleyRenderTexture;
        Graphics.Blit(src,dest,material);
    }

}
