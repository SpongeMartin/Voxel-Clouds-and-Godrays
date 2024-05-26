Shader "Unlit/CloudShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
    }
    SubShader
    {
        Cull Off ZWrite Off ZTest Always

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

            struct v2f {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 viewVector : TEXCOORD1;
            };

            sampler2D _MainTex;
            sampler2D _CameraDepthTexture;

            Texture2D<float4> _SimplexNoise;
            Texture3D<float4> _WorleyFBM;
            Texture2D<float4> _BlueNoise;

            SamplerState sampler_SimplexNoise;
            SamplerState sampler_WorleyFBM;
            SamplerState sampler_BlueNoise;

            float4 _MainTex_ST;
            float3 _BoundsMin;
            float3 _BoundsMax;
            int _NumSteps;
            float _DensityMultiplier;
            float _DensityThreshold;
            float _CloudScale;
            float3 _CloudOffset;
            float _LightAbsorptionThroughCloud;
            float4 _ShapeNoiseWeights;
            float _DensityOffset;
            int _NumStepsLight;
            float _LightAbsorptionTowardSun;
            float _DarknessThreshold;

            v2f vert (appdata v) {
                v2f output;
                output.pos = UnityObjectToClipPos(v.vertex);
                output.uv = v.uv;
                float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
                output.viewVector = mul(unity_CameraToWorld, float4(viewVector,0));
                return output;
            }

            float remap(float v, float minOld, float maxOld, float minNew, float maxNew) {
                return minNew + (v-minOld) * (maxNew - minNew) / (maxOld-minOld);
            }

            float beer(float d) {
                float beer = exp(-d);
                return beer;
            }

            float henyeyGreenstein(float a, float g) {
                float g2 = g*g;
                return (1-g2) / (4*3.1415*pow(1+g2-2*g*(a), 1.5));
            }

            float phase(float a) {
                float blend = .5;
                float G = 0;
                float henyeyBlend = henyeyGreenstein(a,G) * (1-blend) + henyeyGreenstein(a,-G) * blend;
                return G + henyeyBlend* G;
            }

            float sampleDensity(float3 rayPos) {
                int mipLevel = 0;
                float3 size = _BoundsMax - _BoundsMin;
                float3 uvw = (size * .5 + rayPos) * 0.001 * _CloudScale;
                float3 shapeSamplePos = uvw;

                float heightPercent = (rayPos.y - _BoundsMin.y) / size.y;
                float heightGradient = saturate(remap(heightPercent,0.0,.2,0,1)) * saturate(remap(heightPercent,1,.7,0,1));
                float4 shapeNoise = _WorleyFBM.SampleLevel(sampler_WorleyFBM,shapeSamplePos,mipLevel);
                float4 normalizedShapeWeights = _ShapeNoiseWeights / dot(_ShapeNoiseWeights,1);
                float shapeFBM = dot(shapeNoise,normalizedShapeWeights) * heightGradient;
                float baseShapeDensity = shapeFBM + _DensityOffset * .1;

                if(baseShapeDensity > 0){
                    return baseShapeDensity * _DensityMultiplier * 0.1;
                }
                return 0;
            }

            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir) { //pove kje sekamo kvadrat
                float3 t0 = (boundsMin - rayOrigin) / rayDir;
                float3 t1 = (boundsMax - rayOrigin) / rayDir;
                float3 tmin = min(t0, t1);
                float3 tmax = max(t0, t1);
                
                float dstA = max(max(tmin.x, tmin.y), tmin.z);
                float dstB = min(tmax.x, min(tmax.y, tmax.z));

                float dstToBox = max(0, dstA);
                float dstInsideBox = max(0, dstB - dstToBox);
                return float2(dstToBox, dstInsideBox);
            }

            float lightmarch(float3 p) { // ray-marcham preko volumna proti viru svetlobe
                float3 dirToLight = _WorldSpaceLightPos0.xyz;
                float dstInsideBox = rayBoxDst(_BoundsMin, _BoundsMax, p, dirToLight).y;
                
                float transmittance = 1;
                float stepSize = dstInsideBox/_NumStepsLight;
                float totalDensity = 0;

                for (int step = 0; step < _NumStepsLight; step ++) {
                    p += dirToLight * stepSize;
                    totalDensity += max(0,sampleDensity(p) * stepSize);
                }

                transmittance = beer(totalDensity*_LightAbsorptionTowardSun);
                return _DarknessThreshold + transmittance * (1-_DarknessThreshold);
            }

            float4 debugDrawNoise(float2 uv) {
                int debugViewMode = 1;
                bool debugShowAllChannels = false;
                float4 debugChannelWeight = float4(1,1,1,0.5);
                bool debugGreyscale = false;
                float4 channels = 0;
                float3 samplePos = float3(uv.x,uv.y, 0);

                if (debugViewMode == 1) {
                    channels = _SimplexNoise.SampleLevel(sampler_SimplexNoise, samplePos, 0);
                }
                else if (debugViewMode == 2) {
                    channels = _WorleyFBM.SampleLevel(sampler_WorleyFBM, samplePos, 0);
                }

                if (debugShowAllChannels) {
                    return channels;
                }
                else {
                    float4 maskedChannels = (channels*debugChannelWeight);
                    if (debugGreyscale || debugChannelWeight.w == 1) {
                        return dot(maskedChannels,1);
                    }
                    else {
                        return maskedChannels;
                    }
                }
            }

            float2 squareUV(float2 uv) {
                float width = _ScreenParams.x;
                float height =_ScreenParams.y;
                float scale = 1000;
                float x = uv.x * width;
                float y = uv.y * height;
                return float2 (x/scale, y/scale);
            }

            fixed4 frag (v2f i) : SV_Target
            {
                
                /*float debugTileAmount = 1.0;
                float viewerSize = 1.0;
                float width = _ScreenParams.x;
                float height =_ScreenParams.y;
                float minDim = min(width, height);
                float x = i.uv.x * width;
                float y = (1-i.uv.y) * height;

                if (x < minDim*viewerSize && y < minDim*viewerSize) {
                    //return debugDrawNoise(float2(x/(minDim*viewerSize)*debugTileAmount, y/(minDim*viewerSize)*debugTileAmount));
                }*/

                //Properties
                

                float3 rayOrigin = _WorldSpaceCameraPos;
                float viewLength = length(i.viewVector);
                float3 rayDir = i.viewVector / viewLength;
                float nonLinearDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture,i.uv);
                float depth = LinearEyeDepth(nonLinearDepth) * length(i.viewVector);
                float2 rayBoxInfo = rayBoxDst(_BoundsMin,_BoundsMax,rayOrigin,rayDir);
                float dstToBox = rayBoxInfo.x;
                float dstInsideBox = rayBoxInfo.y;

                float randomOffset = _BlueNoise.SampleLevel(sampler_BlueNoise, squareUV(i.uv*3), 0); //Blue noise je namenjen izpiljenju detajlov v oblakih (ni velikega vpliva)
                randomOffset *= 4;

                float dstTravelled = randomOffset;
                float3 entryPoint = rayOrigin + rayDir * dstToBox; //Vstopna točka žarka v notranjost kvadra
                float dstLimit = min(depth - dstToBox,dstInsideBox);
                const float stride = 8; // kako daleč pomaknemo žarek, ko vzorčimo znotraj volumna
                float transmittance = 1;
                float3 lightAttenuation = 0;
                
                
                float cosAngle = dot(rayDir, _WorldSpaceLightPos0.xyz);
                float phaseVal = 1;

                while (dstTravelled < dstLimit) { //Dokler smo še znotraj kvadra
                    float3 rayPos = entryPoint + rayDir * dstTravelled;
                    float density = sampleDensity(rayPos); //Vzorčimo gostoto
                    if (density > 0) {
                        float lightTransmittance = lightmarch(rayPos); //Vzorčimo še prodornost luči
                        lightAttenuation += density * stride * transmittance * lightTransmittance * phaseVal;
                        transmittance *= exp(-density * stride * _LightAbsorptionThroughCloud);
                        if (transmittance < 0.001) {
                            break;
                        }
                    }
                    dstTravelled += stride;
                }

                float3 backgroundCol = tex2D(_MainTex,i.uv);
                float3 cloudCol = lightAttenuation * float3(1,1,1);
                float3 col = backgroundCol * transmittance + cloudCol;
                return float4(col,0);

            }
            ENDCG
        }
    }
}
