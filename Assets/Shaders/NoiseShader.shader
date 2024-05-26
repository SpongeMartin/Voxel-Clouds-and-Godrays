Shader "Custom/NoiseShader"
{
    Properties
    {
        _MainTex ("Base (RGB)", 3D) = "white" {}
        _SliceDepth ("Slice Depth", Range(0,1)) = 0.5
        _Scale ("Scale", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            struct appdata_t
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 texcoord : TEXCOORD0;
            };

            struct v2f
            {
                float2 texcoord : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 worldPos : TEXCOORD1;
            };

            sampler3D _MainTex;
            float _SliceDepth;
            float _Scale;

            v2f vert(appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.texcoord;
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 scaledPos = i.worldPos * _Scale;
                float3 tex3DCoords = scaledPos;
                fixed4 col = tex3D(_MainTex, tex3DCoords);
                return col;
            }
            ENDCG
        }
    }
}