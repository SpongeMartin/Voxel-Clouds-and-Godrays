Shader "Unlit/Clouds"
{
    Properties
    {
        _MainTex ("Texture", 3D) = "white" {}
        _PerlinTex("PerlinTex",3D) = "" {}
        _NumSteps ("Number of steps",int) = 10
        _StepSize ("Stepsize", range(0,1)) = 0.01
        _DensityScale ("Density",range(0,1)) = 0.2
        _Sphere ("Sphere", Vector) = (0,0,0,0)
        _Alpha ("Alpha",float) = 0.02
        _Offset("Offset",Vector) = (0,0,0,0)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        //Blend One OneMinusSrcAlpha

        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma multi_compile_fog
            
            #include "UnityCG.cginc"

            #define EPSILON 0.00001f

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                //float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD0;
                float3 objectVertex : TEXCOORD1;
                //float3 vectorToSurface : TEXCOORD1;
            };

            sampler3D _MainTex;
            Texture3D<half> _PerlinTex;
            float4 _MainTex_ST;
            float _DensityScale;
            float _NumSteps;
            float _StepSize;
            float4 _Sphere;
            float _Alpha;
            float3 _Offset;
            SamplerState linear_repeat_sampler;

            v2f vert (appdata v)
            {
                v2f o;
                o.objectVertex = v.vertex;
                float3 worldVertex = mul(unity_ObjectToWorld, v.vertex).xyz;
                //o.vectorToSurface = worldVertex - _WorldSpaceCameraPos;
                o.vertex = UnityObjectToClipPos(v.vertex);
                //o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                //UNITY_TRANSFER_FOG(o,o.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            float hg(float a, float g) {
                float g2 = g*g;
                return (1-g2) / (4*3.1415*pow(1+g2-2*g*(a), 1.5));
            }

            float4 BlendUnder(float4 color, float4 newColor)
            {
                color.rgb += (1.0 - color.a) * newColor.a * newColor.rgb;
                color.a += (1.0 - color.a) * newColor.a;
                return color;
            }


            float rayMarch(float3 rayOrigin, float3 rayDirection){
                float density;
                for(int i = 0; i < _NumSteps; i++){
                    rayOrigin += (rayDirection * _StepSize);
                    float sphereDist = distance(rayOrigin,_Sphere.xyz);
                    if(sphereDist < _Sphere.w){
                        density += 0.1 * _DensityScale;
                    } else {

                    }
                }
                return density;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 worldPosition = i.worldPos;
                float3 cameraPosition = _WorldSpaceCameraPos;
                float3 ro = worldPosition;
                float3 rd = normalize(worldPosition - cameraPosition);
                int textureSize = 128;
                float3 roo = ro;
                //_Sphere = mul(unity_ObjectToWorld,_Sphere);
                
                
                float density = 0;
                
                for (int ns = 0;ns <_NumSteps; ns++){
                    ro += rd * _StepSize;
                    float3 uvw = (ro / 128);
                    
                    float3 sampledDensity = (_PerlinTex.SampleLevel(linear_repeat_sampler, uvw, 0).r);
                    density += sampledDensity * _DensityScale;
                }
                float4 result = float4(exp(-density),0,0,0.5); 
                return result;
                //return float4(density,density,density,density);


                /*float3 ro = i.objectVertex;
                float3 rd = mul(unity_WorldToObject, float4(normalize(i.vectorToSurface), 1));
                float4 color = float4(0, 0, 0, 0);
                float3 samplePosition = ro;
                for (int i = 0; i < _NumSteps; i++)
                {
                    

                    // Accumulate color only within unit cube bounds
                    if(max(abs(samplePosition.x), max(abs(samplePosition.y), abs(samplePosition.z))) < 0.5f + EPSILON)
                    {
                        float4 sampledColor = tex3D(_PerlinTex, samplePosition + float3(0.5f, 0.5f, 0.5f));
                        sampledColor.a *= _Alpha;
                        color = BlendUnder(color, sampledColor);
                        samplePosition += rd * _StepSize;
                    }
                }

                return color;*/

            }
            ENDCG
        }
    }
}
