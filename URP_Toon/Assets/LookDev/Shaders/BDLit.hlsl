
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

float remap(float value, float inputMin, float inputMax, float outputMin, float outputMax)
{
    return (value - inputMin) * ((outputMax - outputMin) / (inputMax - inputMin)) + outputMin;
}
void GetToonLit(float3 WorldNormal, float3 WorldPos, float Threshold, out float3 Direction, out float3 MainLightColor, out float3 AdditionalColor, out float DistAttenuation , out float AdditionalDistAttenuation, out float ShadowAttenuation,out float3 MainLighting,out float3 AdditionalLighting)
{
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

#if SHADOWS_SCREEN
		float4 clipPos = TransformWorldToHClip(WorldPos);
		float4 shadowCoord = ComputeScreenPos(clipPos);
#else

    float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
#endif
    Light mainLight = GetMainLight(shadowCoord);
    Direction = mainLight.direction;
    MainLightColor = mainLight.color;
	
#ifdef _GET_SELFSHADOW_ON
    DistAttenuation = mainLight.distanceAttenuation ; 
	ShadowAttenuation = mainLight.shadowAttenuation; //でメインライトの影取得。　別々にした
#else
    DistAttenuation = mainLight.distanceAttenuation;
	
	#endif
    float3 additionalLighting;
	#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, WorldPos);
        Direction += light.direction;
	//AdditionalColor = light.color ;        
	AdditionalDistAttenuation = light.distanceAttenuation ;
	remap(AdditionalDistAttenuation,0, 1,10, 100);
	additionalLighting += step(.001-AdditionalDistAttenuation,0)*light.color;        //追加ライトの2値化＆色付け
	ShadowAttenuation *=  light.shadowAttenuation;	//影のAttenuationは乗算で黒く
	}
	//additionalLighting  *=0.01;
    #endif
    //MainLightColor = additionalLighting;
    //float DistAttenuation;
    //float AdditionalDistAttenuation;
    AdditionalColor = float3(0, 0, 0);
 //   Light mainLight = GetMainLight();
            
    //-------------ライティングのみ
    // ピクセルの法線とライトの方向の内積を計算する
    float t = dot(WorldNormal, mainLight.direction);
                // 内積の値を0以上の値にする
    t = remap(t,-1,1,0,1);
                //---------------------------------
    t = step(1-t, Threshold);   //先に2値化することで影の範囲を調整する。
               //float shadowAttenuation;
                   //float shadowAttenuation;
   //ShadowAttenuation = 2*ShadowAttenuation; 
    //MainLight_float(WorldPos, Direction, Color, AdditionalColor, DistAttenuation, AdditionalDistAttenuation, ShadowAttenuation);
    DistAttenuation = remap(DistAttenuation,0, 2, 0, 1);
    AdditionalDistAttenuation = remap(AdditionalDistAttenuation,0, 2, 0, 1);
   // ShadowAttenuation *= 0.01;      //shadowAttenはライトが触れたときに値が変わってる？ <---　ポイントライト範囲に入ると色がつくので?
    
   // ShadowAttenuation = step(t*ShadowAttenuation+DistAttenuation , Threshold); //なぜか明るいほうが－1になってるので反転suru
   // LitShadAttenuation = AdditionalDistAttenuation;
    AdditionalLighting = additionalLighting;
    MainLighting = step(1-t, Threshold)*MainLightColor;
   // Color = Color * 0.1;

}
//


/////////////////////////////////////////////
///////// Depth Normal pass         /////////
///////////////////////////////////////////////
            #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"

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
