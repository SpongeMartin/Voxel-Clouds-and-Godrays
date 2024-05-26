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

            Texture3D<float4> _SimplexNoise;
            Texture3D<float4> _WorleyFBM;

            SamplerState sampler_SimplexNoise;
            SamplerState sampler_WorleyFBM;

            float4 _MainTex_ST;
            float3 _BoundsMin;
            float3 _BoundsMax;
            int _NumSteps;
            float _DensityMultiplier;
            float _DensityThreshold;
            float _CloudScale;
            float3 _CloudOffset;

            v2f vert (appdata v) {
                v2f output;
                output.pos = UnityObjectToClipPos(v.vertex);
                output.uv = v.uv;
                float3 viewVector = mul(unity_CameraInvProjection, float4(v.uv * 2 - 1, 0, -1));
                output.viewVector = mul(unity_CameraToWorld, float4(viewVector,0));
                return output;
            }

            float sampleDensity(float3 pos){
                float3 uvw = pos * _CloudScale * 0.001 + _CloudOffset * 0.01;
                float4 shape = _SimplexNoise.SampleLevel(sampler_SimplexNoise, uvw, 0);
                float density = max(0,shape.r - _DensityThreshold) * _DensityMultiplier;
                return density;
            }

            float2 rayBoxDst(float3 boundsMin, float3 boundsMax, float3 rayOrigin, float3 rayDir) {
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

            fixed4 frag (v2f input) : SV_Target
            {
                float4 col = tex2D(_MainTex, input.uv);
                float3 ro = _WorldSpaceCameraPos;
                float3 rd = normalize(input.viewVector);

                float nonLinDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, input.uv);
                float depth = LinearEyeDepth(nonLinDepth) * length(input.viewVector);

                float2 rayBoxInfo = rayBoxDst(_BoundsMin, _BoundsMax, ro, rd);
                float dToBox = rayBoxInfo.x;
                float dInsideBox = rayBoxInfo.y;

                float dTravelled = 0;
                float stepSize = dInsideBox / _NumSteps;
                float dLimit = min(depth - dToBox, dInsideBox);

                float totalDensity = 0;
                while(dTravelled < dLimit){
                    float3 rp = ro + rd * (dToBox + dTravelled);
                    totalDensity += sampleDensity(rp) * stepSize;
                    dTravelled += stepSize;
                }

                float transmittance = exp(-totalDensity);

                return col * transmittance;

            }
            ENDCG
        }
    }
}
