Shader "BD/PostProcess/DepthNormals"
{
    HLSLINCLUDE
#include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

        TEXTURE2D_X(_MainTex);
    SAMPLER(sampler_MainTex);
    float _Weight;
    float _DepthOrNormal;
    float4x4 _ViewToWorld;

    half4 Frag(Varyings i) : SV_Target
    {
        float4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

        float depth = SampleSceneDepth(i.uv);
        float3 normal = SampleSceneNormals(i.uv);

        depth = Linear01Depth(depth, _ZBufferParams);
        //View‹óŠÔ‚©‚çWorld‹óŠÔ‚É•ÏŠ·
        normal = mul((float3x3)_ViewToWorld, normal);

        half4 color = float4(normal,depth);

        return color;
    }
        ENDHLSL

        SubShader
    {
        Cull Off ZWrite Off ZTest Always
            Pass
        {
            HLSLPROGRAM
                #pragma vertex Vert
                #pragma fragment Frag
            ENDHLSL
        }
    }
}