Shader "Custom/VolumetricSphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (0,0,0,1)
        _Opacity ("Opacity", Range(0, 1)) = 0.5
        _Absorption ("Absorption Coefficient", Range(0, 2)) = 0.1
        _Scattering ("Scattering Coefficient", Range(0, 2)) = 0.1
        _SphereRadius ("Sphere Radius", Float) = 1.0
        _StepSize ("RayMarch Stride", Range(0.00001,2)) = 0.2
        _Density ("Density", Range(0,1)) = 1
        _HenyeyG ("Henyey-Greenstein Asymmetry", range(-1,1)) = 0.8
    }
    SubShader
    {
        Tags { "Queue"="Transparent" }
        Blend SrcAlpha OneMinusSrcAlpha
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            #define PI 3.141592653589793
            
            struct appdata
            {
                float4 vertex : POSITION;
            };
            
            struct v2f
            {
                float4 pos : SV_POSITION;
                float3 worldPos : TEXCOORD0;
            };
            
            v2f vert(appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            struct IsectData {
                float t0;
                float t1;
                bool inside;
            };

            sampler2D _MainTex;
            float4 _Color;
            float _Opacity;
            float _Absorption; //sigma_a
            float _Scattering; //sigma_s
            float _SphereRadius;
            float _StepSize;
            float _HenyeyG;
            float3 _LightPosition;
            float _Density;
            float t0;
            float t1;
            int p[512];


            
            float fade(float t) {
                return t * t * t * (t * (t * 6 - 15) + 10);
            }

            float lerp(float t, float a, float b) {
                return a + t * (b - a);
            }

            float grad(int hash, float x, float y, float z) {
                int h = hash & 15;
                float u = h < 8 ? x : y;
                float v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
                return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
            }

            float noise(float3 pos) {
                int X = (int)floor(pos.x) & 255;
                int Y = (int)floor(pos.y) & 255;
                int Z = (int)floor(pos.z) & 255;

                float x = pos.x - floor(pos.x);
                float y = pos.y - floor(pos.y);
                float z = pos.z - floor(pos.z);

                float u = fade(x);
                float v = fade(y);
                float w = fade(z);

                int A = p[X] + Y;
                int AA = p[A] + Z;
                int AB = p[A + 1] + Z;
                int B = p[X + 1] + Y;
                int BA = p[B] + Z;
                int BB = p[B + 1] + Z;

                return lerp(w, lerp(v, lerp(u, grad(p[AA], x, y, z),
                                            grad(p[BA], x - 1, y, z)),
                                    lerp(u, grad(p[AB], x, y - 1, z),
                                            grad(p[BB], x - 1, y - 1, z))),
                            lerp(v, lerp(u, grad(p[AA + 1], x, y, z - 1),
                                            grad(p[BA + 1], x - 1, y, z - 1)),
                                    lerp(u, grad(p[AB + 1], x, y - 1, z - 1),
                                            grad(p[BB + 1], x - 1, y - 1, z - 1))));
            }

            float nrand(float2 uv){ //random
                return frac(sin(dot(uv, float2(12.9898, 78.233))) * 43758.5453);
            }

            bool CalculateIntersectionPoint(float3 rayOrigin, float3 rayDirection, out IsectData isect){ //On a sphere
                float3 localSphereCenter = float3(0, 0, 0); 

                float3 sphereCenter = mul(unity_ObjectToWorld, float4(localSphereCenter, 1.0)).xyz;
                isect.inside = length(rayOrigin - sphereCenter) < _SphereRadius/2;

                float t = dot(sphereCenter - rayOrigin,rayDirection);
                float3 p = rayOrigin + rayDirection * t;
                float y = length(sphereCenter-p);
                if (y < _SphereRadius/2)
                {
                    float x = sqrt(_SphereRadius/2 * _SphereRadius/2 - y * y);
                    float t_0 = t - x;
                    float t_1 = t + x;
                    isect.t0 = min(t_0,t_1);
                    isect.t1 = max(t_0,t_1);
                    return true;
                }
                return false;

            }


            float getTransmission(float3 rayOrigin,float3 rayDirection,IsectData isect){
                //Beer's Law - returns sample attenuation. ~ based on Absorption and Scattering.
                //Absorption - how much light the volume absorbs.
                //Scattering - how much light bounces off photons within the volume.
                float3 p1 = rayOrigin + rayDirection * isect.t0;
                float3 p2 = rayOrigin + rayDirection * isect.t1;
                float distance = length(p1 - p2);
                return exp(-distance * _Density * (_Absorption + _Scattering));
            }

            float phase(float angle){ //cos-theta angle for which the scattering is possible.
                float g2 = _HenyeyG * _HenyeyG;
                float denom = 1.0 + g2 - 2.0 * _HenyeyG * angle;
                return (1.0 / (4.0 * PI)) * ((1.0 - g2) / (denom * sqrt(denom)));
            }

            void rayMarch(float3 rayOrigin,float3 rayDirection,IsectData isect, out float3 result, out float transparency){
                int ns = ceil(abs(isect.t1 - isect.t0) / _StepSize);
                int d = 2;
                float stepSize = abs(isect.t1 - isect.t0) / ns;
                result = float3(0,0,0);
                transparency = 1;
                float sampleAttenuation = exp(-stepSize * _Density * (_Absorption + _Scattering));
                IsectData isectLi;
                float3 lightColor = float3(1,1,1);
                for (int n = 0; n<ns;++n){ 
                    float t = isect.t0 + stepSize * (n + nrand(float2(0,1)));  //nrand stochastic sampling
                    float3 origin = rayOrigin + t * rayDirection;
                    _Density = (1 + noise(origin)) / 2;
                    transparency *= sampleAttenuation;
                    
                    if (transparency < 1e-3){ //russian roulette
                        if (nrand(float2(0,1) > 1.f/d)){
                            break;
                        } else {
                            transparency *= d;
                        }
                    }
                    
                    float3 lightDir = normalize(_LightPosition);
                    CalculateIntersectionPoint(origin,lightDir,isectLi);
                    float angle = rayDirection * lightDir;
                    float lightAttenuation = exp(-_Density * isectLi.t1 * (_Absorption + _Scattering));
                    result = result + _Density * _Scattering * phase(angle)  * lightAttenuation * lightColor * stepSize;
                }
            }
                 
            float4 frag(v2f i) : SV_Target
            {
                IsectData isect;
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.worldPos - rayOrigin);
                float4 accumulatedColor = float4(0,0,0,0);

                _LightPosition = _WorldSpaceLightPos0.xyz;
                CalculateIntersectionPoint(rayOrigin,rayDirection,isect);
                
                float transmission = getTransmission(rayOrigin,rayDirection,isect);
                accumulatedColor += (1 - transmission) * _Color;
                
                float3 rayMarchResult;
                float rayMarchTransparency;

                rayMarch(rayOrigin,rayDirection,isect,rayMarchResult,rayMarchTransparency);

                return float4(accumulatedColor.rgb * rayMarchResult, (1 - (transmission) * rayMarchTransparency));
            }
            ENDCG
        }
    }
}
