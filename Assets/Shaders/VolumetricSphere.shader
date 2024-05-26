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
            Texture3D<half> _NoiseTex;
            static const int p[256] = {151, 160, 137, 91, 90, 15, 131, 13,
            201, 95, 96, 53, 194, 233, 7, 225, 140, 36, 103, 30, 69, 142,
            8, 99, 37, 240, 21, 10, 23, 190, 6, 148, 247, 120, 234, 75,
            0, 26, 197, 62, 94, 252, 219, 203, 117, 35, 11, 32, 57, 177,
            33, 88, 237, 149, 56, 87, 174, 20, 125, 136, 171, 168, 68,
            175, 74, 165, 71, 134, 139, 48, 27, 166, 77, 146, 158, 231,
            83, 111, 229, 122, 60, 211, 133, 230, 220, 105, 92, 41, 55, 
            46, 245, 40, 244, 102, 143, 54, 65, 25, 63, 161, 1, 216, 80, 
            73, 209, 76, 132, 187, 208, 89, 18, 169, 200, 196, 135, 130, 
            116, 188, 159, 86, 164, 100, 109, 198, 173, 186, 3, 64, 52, 
            217, 226, 250, 124, 123, 5, 202, 38, 147, 118, 126, 255, 82, 
            85, 212, 207, 206, 59, 227, 47, 16, 58, 17, 182, 189, 28, 42, 
            223, 183, 170, 213, 119, 248, 152, 2, 44, 154, 163, 70, 221, 
            153, 101, 155, 167, 43, 172, 9, 129, 22, 39, 253, 19, 98, 108, 
            110, 79, 113, 224, 232, 178, 185, 112, 104, 218, 246, 97, 228, 
            251, 34, 242, 193, 238, 210, 144, 12, 191, 179, 162, 241, 81, 
            51, 145, 235, 249, 14, 239, 107, 49, 192, 214, 31, 181, 199, 
            106, 157, 184, 84, 204, 176, 115, 121, 50, 45, 127, 4, 150, 
            254, 138, 236, 205, 93, 222, 114, 67, 29, 24, 72, 243, 141, 
            128, 195, 78, 66, 215, 61, 156, 180};



            float lerp(float t, float a, float b) {
                return a + t * (b - a);
            }

            float grad(int hash, float x, float y, float z) {
                int h = hash & 15;
                float u = h < 8 ? x : y;
                float v = h < 4 ? y : (h == 12 || h == 14 ? x : z);
                return ((h & 1) == 0 ? u : -u) + ((h & 2) == 0 ? v : -v);
            }


            float fade(float t) {return t * t * t * (t * (t * 6 - 15) + 10); }

            float perlinNoise(float3 pos) {
                int3 pi = int3(floor(pos) % 255);
                int x = pos.x - floor(pos.x), y = pos.y - floor(pos.y), z = pos.z - floor(pos.z);
                float u = fade(x), v = fade(y), w = fade(z);
                int A = p[pi.x  ]+pi.y, AA = p[A]+pi.z, AB = p[A+1]+pi.z,
                    B = p[pi.x+1]+pi.y, BA = p[B]+pi.z, BB = p[B+1]+pi.z;


                return lerp(w, lerp(v, lerp(u, grad(p[AA  ], x  , y  , z   ),
                                            grad(p[BA  ], x-1, y  , z   )),
                                    lerp(u, grad(p[AB  ], x  , y-1, z   ),
                                            grad(p[BB  ], x-1, y-1, z   ))),
                            lerp(v, lerp(u, grad(p[AA+1], x  , y  , z-1 ),
                                            grad(p[BA+1], x-1, y  , z-1 )),
                                    lerp(u, grad(p[AB+1], x  , y-1, z-1 ),
                                            grad(p[BB+1], x-1, y-1, z-1 ))));
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

            float HenyeyGreenstein(float g, float cos_theta) {
                float denom = 1.0f + g * g - 2.0f * g * cos_theta;
                return (1.0f / (4.0f * PI)) * ((1.0f - g * g) / (denom * sqrt(denom)));
            }

            float Mie(float g, float cos_theta) {
                float denom = 1.0f + g * g - 2.0f * g * cos_theta;
                return (3.0f / (8.0f * PI)) * (((1 - g * g) * (1 + cos_theta * cos_theta)) / ((2.0f + g * g) * (denom * sqrt(denom)))); 
            }

            float Rayleigh(float cos_theta) {
                return (3.0f / (16.0f * PI)) * (1 + cos_theta * cos_theta);
            }

            float phase(float g, float cos_theta, int pf) {
                float p = 0.0f;

                if (pf == 0) p = HenyeyGreenstein(g, cos_theta);
                if (pf == 1) p = Mie(g, cos_theta);
                if (pf == 2) p = Rayleigh(cos_theta);

                return p;
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

            float eval_density(float3 p){ 
                float freq = 1;
                return (1 + perlinNoise(float3(p.x * freq, p.y * freq, p.z * freq))) * 0.5;
            }

            float getNoise(float3 pos) {
                float3 uvw = pos;
                

                return 1.5;
            }

            void rayMarch(float3 rayOrigin,float3 rayDirection,IsectData isect, out float3 result, out float transparency){
                int ns = ceil(abs(isect.t1 - isect.t0) / _StepSize);
                int d = 2;
                float stepSize = abs(isect.t1 - isect.t0) / ns;
                result = float3(0,0,0);
                transparency = 1;
                IsectData isectLi;
                float3 lightColor = float3(1,1,1);
                float3 lightDir = normalize(_LightPosition);
                float extinctionCoef = _Absorption + _Scattering;
                // raymarch loop
                for (int n = 0; n<ns;++n){ 
                    float t = isect.t0 + stepSize * (n + nrand(float2(0,1)));  //nrand stochastic sampling
                    float3 x = rayOrigin + t * rayDirection; //which x are we handling
                    float density = eval_density(x);
                    float sampleAttenuation = exp(-stepSize * density * extinctionCoef);
                    transparency *= sampleAttenuation;
                    
                    //In-scattering
                    if(density > 0.001f){
                        IsectData isect_light_ray;
                        CalculateIntersectionPoint(x,lightDir,isect_light_ray);
                        int liSteps = ceil(isect_light_ray.t1 / stepSize);
                        float liStepSize = isect_light_ray.t1/liSteps;
                        float tau = 0;
                        //Raymarch along lightray
                        for (int nl = 0; nl < liSteps; ++nl){
                            float tLi = liStepSize * (nl + 0.5);
                            float3 liSample = x + lightDir * tLi;
                            tau += eval_density(liSample);
                        }
                        float liRayAttenuation = exp(-tau * liStepSize * extinctionCoef);
                        result +=   lightColor * liRayAttenuation * 
                                    phase(_HenyeyG,rayDirection * lightDir,0) * // fix
                                    _Scattering * transparency * stepSize * density;
                    }

                    if (transparency < 1e-3){ //russian roulette
                        if (nrand(float2(0,1) > 1.f/d)){
                            break;
                        } else {
                            transparency *= d;
                        }
                    }
                    
                    /*CalculateIntersectionPoint(x,lightDir,isectLi);
                    float angle = 
                    float lightAttenuation = exp(-_Density * isectLi.t1 * (_Absorption + _Scattering));
                    result = result + _Density * _Scattering * phase(_HenyeyG,angle,0)  * lightAttenuation * lightColor * stepSize;*/
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

                return float4(saturate(rayMarchResult),1);
            }
            ENDCG
        }
    }
}
