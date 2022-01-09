//////////////////////////////
////// 参考　https://forum.unity.com/threads/shadow-attenuation-issue-on-urp-spot-light-in-custom-lighting.928908/
////// 参考 https://github.com/ColinLeung-NiloCat/UnityURPToonLitShaderExample.git
////////////
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"



float remap(float value, float inputMin, float inputMax, float outputMin, float outputMax)
{
    return (value - inputMin) * ((outputMax - outputMin) / (inputMax - inputMin)) + outputMin;
}

//追加ライトぶんのライティング計算。影も落ちた状態
half3 ShadeSingleLight( Light light, bool isAdditionalLight)
{
    //half3 N = lightingData.normalWS;
    half3 L = light.direction;

    //half NoL = dot(N, L);

    half lightAttenuation = 1;

    // light's distance & angle fade for point light & spot light (see GetAdditionalPerObjectLight(...) in Lighting.hlsl)
    // Lighting.hlsl -> https://github.com/Unity-Technologies/Graphics/blob/master/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl
    half distanceAttenuation = min(4, light.distanceAttenuation); //clamp to prevent light over bright if point/spot light too close to vertex
    half lighting = distanceAttenuation * light.shadowAttenuation;
    //remap(lighting, 0, 0.1, 0, 1);
    half3 additionalLighting =step(0.001,lighting)*  light.color; //追加ライトの2値化＆色付け
    return additionalLighting;
}

void GetToonLit(float3 WorldNormal, float3 WorldPos, float Threshold, out float3 Direction, out float3 MainLightColor, out float3 AdditionalColor, out float DistAttenuation , out float AdditionalDistAtten, out float ShadowAtten,out float3 MainLighting,out float3 AdditionalLighting)
{
        //////////////////////////////////////////////////////////////////////////////////
    // Light struct is provided by URP to abstract light shader variables.
    // It contains light's
    // - direction
    // - color
    // - distanceAttenuation 距離などによる減衰
    // - shadowAttenuation  落ち影による減衰
    //
    // URP take different shading approaches depending on light and platform.
    // You should never reference light shader variables in your shader, instead use the 
    // -GetMainLight()
    // -GetLight()
    // funcitons to fill this Light struct.
    //////////////////////////////////////////////////////////////////////////////////
        //==============================================================================================
    // Main light is the brightest directional light.
    // It is shaded outside the light loop and it has a specific set of variables and shading path
    // so we can be as fast as possible in the case when there's only a single directional light
    // You can pass optionally a shadowCoord. If so, shadowAttenuation will be computed.
         #pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
             #pragma multi_compile _ _ADDITIONAL_LIGHT_CALCULATE_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE

#if SHADOWS_SCREEN
		float4 clipPos = TransformWorldToHClip(WorldPos);
		float4 shadowCoord = ComputeScreenPos(clipPos);
#else

    float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
#endif
    Light mainLight = GetMainLight(shadowCoord);
    float3 shadowTestPosWS = WorldPos ;
    Direction = mainLight.direction;
    MainLightColor = mainLight.color;
    DistAttenuation = 0;
#ifdef _GET_SELFSHADOW_ON
    DistAttenuation = mainLight.distanceAttenuation ; 
#endif

    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    half4 shadowParams = GetMainLightShadowParams();
	ShadowAtten = 1;
    ShadowAtten = mainLight.shadowAttenuation; //でメインライトの影取得。　別々にした
    float3 additionalLighting;
	#ifdef _ADDITIONAL_LIGHTS
    // Returns the amount of lights affecting the object being renderer.
    // These lights are culled per-object in the forward renderer of URP.
    float shadowAtten = 0;
    float3 additionalLightSumResult;
    uint additionalLightsCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < additionalLightsCount; ++lightIndex)
    {
    
    // Similar to GetMainLight(), but it takes a for-loop index. This figures out the
        // per-object light index and samples the light buffer accordingly to initialized the
        // Light struct. If ADDITIONAL_LIGHT_CALCULATE_SHADOWS is defined it will also compute shadows.
           int perObjectLightIndex = GetPerObjectLightIndex(lightIndex);
    Light light = GetAdditionalPerObjectLight(perObjectLightIndex, WorldPos);
     light.shadowAttenuation =   AdditionalLightRealtimeShadow(perObjectLightIndex,shadowTestPosWS);
	AdditionalDistAtten = light.distanceAttenuation ;
    additionalLightSumResult += ShadeSingleLight(light, 1);
        
	remap(AdditionalDistAtten,0, 1,10, 100);
        
    }
    AdditionalLighting = additionalLightSumResult; //影のAttenuationは乗算で黒く
    
    #endif
    AdditionalColor = float3(0, 0, 0);
    //-------------ライティングのみ
    // ピクセルの法線とライトの方向の内積を計算する
    float t = dot(WorldNormal, mainLight.direction);
                
    t = remap(t, -1, 1, 0, 1); // 内積の値を0以上の値にする
    t = step(Threshold,t ); //先に2値化することで影の範囲を調整する。
    //---------------------------------
    
    DistAttenuation = remap(DistAttenuation,0, 2, 0, 1);
    AdditionalDistAtten = 1;
    ShadowAtten = step( Threshold,ShadowAtten); 
    MainLighting =t * MainLightColor;

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
