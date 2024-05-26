Shader "Custom/perlin"
{
    Properties
    {
        _NoiseScale("Noise Scale", float) = 1.0
        _NoiseTransform("Noise Transform", Vector) = (0, 0, 0)
        _StepSize("Step Size", float) = 0.1
        _MaxDistance("Max Distance", float) = 10.0
        _NumSteps("Number of steps", int) = 100
        _DensityThreshold("Density Threshold",range(0,1)) = 0.1
    }

    SubShader
    {
        Tags { "RenderType" = "Opaque" }
        LOD 200

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float _NoiseScale;
            float3 _NoiseTransform;
            float _StepSize;
            float _MaxDistance;
            int _NumSteps;
            float _DensityThreshold;
            
            float3 random3D(float3 uvw)
            {
                uvw = dot(uvw, float3(127.1, 311.7, 513.7));
                return -1.0 + 2.0 * frac(sin(uvw) * 43758.5453123);
            }

            float noise3D(float3 uvw)
            {
                uvw *= _NoiseScale;
                uvw += _NoiseTransform;

                float3 gridIndex = floor(uvw);
                float3 gridFract = frac(uvw);
                float3 blur = smoothstep(0.0, 1.0, gridFract);

                float3 blb = gridIndex + float3(0.0, 0.0, 0.0);
                float3 brb = gridIndex + float3(1.0, 0.0, 0.0);
                float3 tlb = gridIndex + float3(0.0, 1.0, 0.0);
                float3 trb = gridIndex + float3(1.0, 1.0, 0.0);
                float3 blf = gridIndex + float3(0.0, 0.0, 1.0);
                float3 brf = gridIndex + float3(1.0, 0.0, 1.0);
                float3 tlf = gridIndex + float3(0.0, 1.0, 1.0);
                float3 trf = gridIndex + float3(1.0, 1.0, 1.0);

                float3 gradBLB = random3D(blb);
                float3 gradBRB = random3D(brb);
                float3 gradTLB = random3D(tlb);
                float3 gradTRB = random3D(trb);
                float3 gradBLF = random3D(blf);
                float3 gradBRF = random3D(brf);
                float3 gradTLF = random3D(tlf);
                float3 gradTRF = random3D(trf);

                float dotBLB = dot(gradBLB, gridFract - float3(0.0, 0.0, 0.0));
                float dotBRB = dot(gradBRB, gridFract - float3(1.0, 0.0, 0.0));
                float dotTLB = dot(gradTLB, gridFract - float3(0.0, 1.0, 0.0));
                float dotTRB = dot(gradTRB, gridFract - float3(1.0, 1.0, 0.0));
                float dotBLF = dot(gradBLF, gridFract - float3(0.0, 0.0, 1.0));
                float dotBRF = dot(gradBRF, gridFract - float3(1.0, 0.0, 1.0));
                float dotTLF = dot(gradTLF, gridFract - float3(0.0, 1.0, 1.0));
                float dotTRF = dot(gradTRF, gridFract - float3(1.0, 1.0, 1.0));

                return lerp(
                    lerp(
                        lerp(dotBLB, dotBRB, blur.x),
                        lerp(dotTLB, dotTRB, blur.x),
                        blur.y
                    ),
                    lerp(
                        lerp(dotBLF, dotBRF, blur.x),
                        lerp(dotTLF, dotTRF, blur.x),
                        blur.y
                    ),
                    blur.z
                ) + 0.5;
            }
            float ComputeDensity(float3 p)
            {
                float3 uvw = p;
                float noise = noise3D(uvw);
                if(noise < _DensityThreshold){
                    return 0;
                }
                return noise;
            }


            v2f vert(appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }



            fixed4 frag(v2f i) : SV_Target
            {
                float3 ro = float3(0, 0, 0); // Camera position
                float3 rd = normalize(float3(i.uv, 1)); // Ray direction
                
                float t = 0.0; // Initial distance along the ray
                float density = 0.0; // Initial density
                float alpha = 1;
                float3 result = float3(0,0,0);

                for (int steps = 0; steps < _NumSteps; steps++) // Max number of steps
                {
                    float3 p = ro + t * rd; // Current position along the ray
                    density = ComputeDensity(p); // Compute density at current position
                    float sampleAttenuation = exp(-_StepSize * density * (0.2));
                    alpha *= sampleAttenuation;
                    // Move forward along the ray based on density
                    t += steps * _StepSize;

                    if (t > _MaxDistance || density < 0.001) // Stop marching if max distance is reached or density is too low
                        break;
                    else{
                        float liT = 0.0;
                        float tau = 0.0;
                        for(int liSteps = 0; liSteps < _NumSteps; liSteps++){
                            float3 liDir = normalize(float3(0,1,0) - p);
                            float3 liSample = p + liDir * liT;
                            liT += liSteps * _StepSize;
                            tau += ComputeDensity(liSample);
                        }
                        float lightAttenuation = exp(-tau * _StepSize * 0.2);
                        result += lightAttenuation * float3(1,1,1) * 0.1 * alpha * _StepSize * density;
                    }
                }

                //density = exp(-density);

                return fixed4(result, (alpha));
            }

            
            ENDCG
        }
    }
}
