Shader "Custom/VolumetricSphere"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (0,0,0,1)
        _Opacity ("Opacity", Range(0, 1)) = 0.5
        _Absorption ("Absorption Coefficient", Range(0, 1)) = 0.1
        _SphereRadius ("Sphere Radius", Float) = 1.0
        _StepSize ("RayMarch Stride", Float) = 0.2
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

            float3 intersectionPoint;
            float t0;
            float t1;

            
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

            sampler2D _MainTex;
            float4 _Color;
            float _Opacity;
            float _Absorption;
            float _SphereRadius;
            float _StepSize;


            // Function to calculate the intersection point between a ray and a sphere
            bool CalculateIntersectionPoint(float3 rayOrigin, float3 rayDirection)
            {
                // Sphere parameters
                float3 localSphereCenter = float3(0, 0, 0); // Local position of the sphere center
                float sphereRadius = _SphereRadius; // Radius of the sphere
                
                // Transform local sphere center to world coordinates
                float3 sphereCenter = mul(unity_ObjectToWorld, float4(localSphereCenter, 1.0)).xyz;
                
                // Ray-sphere intersection algorithm
                float3 oc = rayOrigin - sphereCenter;
                float a = dot(rayDirection, rayDirection);
                float b = 2.0 * dot(oc, rayDirection);
                float c = dot(oc, oc) - (sphereRadius * sphereRadius);
                float3 v = oc - b / (2 * a) * rayDirection;
                float len = length(v);
                float discriminant = 4 * a * (_SphereRadius + len) * (_SphereRadius - len);
                
                // If the discriminant is negative, there are no real roots, meaning the ray misses the sphere
                if (discriminant < 0.0)
                {
                    return false;
                }
                
                // Calculate the intersection points
                float q = (b > 0) ? -0.5 * (b + sqrt(discriminant)) : -0.5 * (b - sqrt(discriminant));
                
                float t_0 = q / a;
                float t_1 = c / q;

                t0 = min(t_0,t_1);
                t1 = max(t_0,t_1);

                
                // Return the nearest intersection point
                return true;
            }

            
            
            float4 frag(v2f i) : SV_Target
            {
                float t = 0.0;
                float3 rayOrigin = _WorldSpaceCameraPos;
                float3 rayDirection = normalize(i.worldPos - rayOrigin);
                float4 accumulatedColor = float4(0.5,0.5,0.5,1);
                int ns = ceil((t1 - t0) / _StepSize);
                float stepSize = (t1 - t0) / ns;
                float scattering = 0.1;
                float transparency = 1;

                CalculateIntersectionPoint(rayOrigin,rayDirection);
                
                //Beer's law
                float3 p1 = rayOrigin + rayDirection * t0;
                float3 p2 = rayOrigin + rayDirection * t1;
                float distance = length(p1 - p2);
                float transmission = exp(-distance * _Absorption);

                //return _Color * (1-transmission);
                return float4(_Color.rgb,1-transmission);
                
            
            }
            ENDCG
        }
    }
}
