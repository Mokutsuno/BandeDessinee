#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
  

               
            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            CBUFFER_START(UnityPerMaterial)
float4 _MainTex_ST;
            CBUFFER_END
float3 _LightDirection;

struct Attributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 texcoord : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float2 uv : TEXCOORD0;
    float4 positionCS : SV_POSITION;
};


float4 GetShadowPositionHClip(Attributes input)
{
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    VertexPositionInputs vertex = GetVertexPositionInputs(input.positionOS.xyz);
    float4 positionCS = vertex.positionCS;

    return positionCS;
}

Varyings ShadowPassVertex(Attributes input)
{
    Varyings output = (Varyings) 0;
    UNITY_SETUP_INSTANCE_ID(input);

    output.uv = TRANSFORM_TEX(input.texcoord, _MainTex);

    // ShadowsCasterPass.hlsl の GetShadowPositionHClip() を参考に
    float3 positionWS = TransformObjectToWorld(input.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(input.normalOS);
    float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, _LightDirection));
#if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
#endif
    output.positionCS = positionCS;

    // オブジェクト空間の座標をMVP変換
   // VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
    //output.positionCS = vertexInput.positionCS; // クリッピング空間の座標 (影が表示されない)    return output;
    return output;
}

half4 ShadowPassFragment(Varyings input) : SV_TARGET
{
   // Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_MainTex, sampler_MainTex)).a, _, _Cutoff);

    clip(SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv).a - 0.5);
    return 0;
}
