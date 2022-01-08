
//#include "Assets/LookDev/Data/Shadows.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"
float remap(float value, float inputMin, float inputMax, float outputMin, float outputMax)
{
    return (value - inputMin) * ((outputMax - outputMin) / (inputMax - inputMin)) + outputMin;
}
void MainLight_float(float3 WorldPos, out float3 Direction, out float3 Color, out float3 AdditionalColor, out float DistAttenuation, out float AdditionalDistAttenuation, out float ShadowAttenuation)
{
	    #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
#pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
#ifdef SHADERGRAPH_PREVIEW
	Direction = float3(0.5, 0.5, 0);
	Color = 1;
	Attenuation = 1;

#else
	#if SHADOWS_SCREEN
		float4 clipPos = TransformWorldToHClip(WorldPos);
		float4 shadowCoord = ComputeScreenPos(clipPos);
	#else

		float4 shadowCoord = TransformWorldToShadowCoord(WorldPos);
	#endif
	Light mainLight = GetMainLight(shadowCoord);
	Direction = mainLight.direction;
	Color = mainLight.color;
	
	#ifdef _GET_SELFSHADOW_ON
    DistAttenuation = mainLight.distanceAttenuation ; 
	ShadowAttenuation = mainLight.shadowAttenuation; //でメインライトの影取得。　別々にした
	#else
    DistAttenuation = mainLight.distanceAttenuation;
	
	#endif
	#if !defined(_MAIN_LIGHT_SHADOWS) || defined(_RECEIVE_SHADOWS_OFF)
	//ShadowAtten = 1.0h;
	#endif
	
	#ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, WorldPos);
        Direction += light.direction;
	AdditionalColor = light.color ;        
	AdditionalDistAttenuation = light.distanceAttenuation ;
	remap(AdditionalDistAttenuation,0, 100, 0, 1);
	Color += AdditionalColor* AdditionalDistAttenuation;
	ShadowAttenuation *=  light.shadowAttenuation;	//影のAttenuationは乗算で黒く
	}
	AdditionalColor *=0.01;
#endif
#endif
}
