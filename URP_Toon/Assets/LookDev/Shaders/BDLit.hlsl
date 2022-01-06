#include "Assets/LookDev/Materials/Toon/GetLighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


void GetToonLit(float3 WorldNormal,float3 WorldPos,  float3 Direction,float Threshold, out float3 Color, out float ShadowAttenuation, out float LitShadAttenuation)
{
    Light mainLight = GetMainLight();
    float strength = dot(mainLight.direction, WorldNormal);
    float oneminusStrength = -1 * (strength - 1);
                
                //-------------ライティングのみ
                // ピクセルの法線とライトの方向の内積を計算する
    float t = dot(WorldNormal, mainLight.direction);
                // 内積の値を0以上の値にする
    t = max(0, t);
                //---------------------------------

                // カメラとオブジェクトの距離(長さ)を取得
                // _WorldSpaceCameraPos：定義済の値　ワールド座標系のカメラの位置
    float cameraToObjLength = length(_WorldSpaceCameraPos - WorldPos);
               //float shadowAttenuation;
                   //float shadowAttenuation;
               
    MainLight_float(WorldPos, Direction, Color, ShadowAttenuation);
    LitShadAttenuation = step(ShadowAttenuation * t, Threshold);

}
//



struct BDAttributes
{
    float4 positionOS : POSITION;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
};

struct BDVaryings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD8; //POSITIONだとエラー起きるのでTEXCOORDで暫定対処
    float2 uv : TEXCOORD0;
    float3 normalWS : TEXCOORD1;
};


/////////////////////////////////////////////
///////// Depth Normal pass         /////////
///////////////////////////////////////////////
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
            Varyings DepthNormalsVertex(Attributes input)
            {
Varyings output = (Varyings) 0;
                UNITY_SETUP_INSTANCE_ID(input);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                output.uv         = TRANSFORM_TEX(input.texcoord, _BaseMap);
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);

VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS, input.tangentOS);
                output.normalWS = NormalizeNormalPerVertex(normalInput.normalWS);

                //LitPassVertexから持ってきた
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR) || defined(REQUIRES_TANGENT_SPACE_VIEW_DIR_INTERPOLATOR)
                real sign = input.tangentOS.w * GetOddNegativeScale();
                half4 tangentWS = half4(normalInput.tangentWS.xyz, sign);
#endif
#if defined(REQUIRES_WORLD_SPACE_TANGENT_INTERPOLATOR)
                output.tangentWS = tangentWS;
#endif

                return
output;
            }

float4 DepthNormalsFragment(Varyings input) : SV_TARGET
{
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

                //LitPassFragmentから持ってきた
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                //input.normalWSからinputData.normalWSに変更
    return float4(PackNormalOctRectEncode(TransformWorldToViewDir(inputData.normalWS, true)), 0.0, 0.0);
}
