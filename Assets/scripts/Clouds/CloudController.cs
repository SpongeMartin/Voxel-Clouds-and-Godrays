using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class CloudController : MonoBehaviour
{
    public Shader shader;
    public Transform container;
    public int numSteps = 10;
    public float cloudScale = 1.0f;

    public float lightAbsorptionThroughCloud = 1;
    public Vector4 shapeNoiseWeights = new Vector4(1,1,1,1);
    public float densityOffset = -4f;
    public float densityMultiplier = -4f;
    public int numStepsLight = 10;
    public float lightAbsorptionTowardSun = 1.5f;
    public float darknessThreshold = 0.25f;

    [Range (0, 1)]
    public float densityThreshold = 1.0f;
    public Vector3 offset = new Vector3(0,0,0);
    public RenderTexture simp;
    public RenderTexture worley;
    public Texture2D blueNoise;
    public Material material;

    void Awake(){
        var weathermap = FindObjectOfType<SimplexNoiseRenderer>();
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
        material.SetFloat("_LightAbsorptionThroughCloud", lightAbsorptionThroughCloud);
        material.SetFloat("_DensityOffset", densityOffset);
        material.SetFloat("_LightAbsorptionTowardSun", lightAbsorptionTowardSun);
        material.SetFloat("_DarknessThreshold", darknessThreshold);
        material.SetInt("_NumStepsLight", numStepsLight);
        material.SetInt("_NumSteps", numSteps);
        material.SetVector("_ShapeNoiseWeights",shapeNoiseWeights);

        var weathermap = FindObjectOfType<SimplexNoiseRenderer>();
        //weathermap.GenerateSimplexNoise();
        material.SetTexture("_SimplexNoise", weathermap.simplexRenderTexture);
        simp = weathermap.simplexRenderTexture;
        var noise = FindObjectOfType<WorleyNoiseRenderer>();
        //noise.GenerateWorleyNoise();
        material.SetTexture("_WorleyFBM", noise.worleyRenderTexture);
        worley = noise.worleyRenderTexture;
        material.SetTexture("_BlueNoise",blueNoise);

        Graphics.Blit(src,dest,material);
    }

}
