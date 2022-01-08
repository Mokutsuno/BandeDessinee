
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
	ShadowAttenuation = mainLight.shadowAttenuation; //�Ń��C�����C�g�̉e�擾�B�@�ʁX�ɂ���
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
	additionalLighting += step(.001-AdditionalDistAttenuation,0)*light.color;        //�ǉ����C�g��2�l�����F�t��
	ShadowAttenuation *=  light.shadowAttenuation;	//�e��Attenuation�͏�Z�ō���
	}
	//additionalLighting  *=0.01;
    #endif
    //MainLightColor = additionalLighting;
    //float DistAttenuation;
    //float AdditionalDistAttenuation;
    AdditionalColor = float3(0, 0, 0);
 //   Light mainLight = GetMainLight();
            
    //-------------���C�e�B���O�̂�
    // �s�N�Z���̖@���ƃ��C�g�̕����̓��ς��v�Z����
    float t = dot(WorldNormal, mainLight.direction);
                // ���ς̒l��0�ȏ�̒l�ɂ���
    t = remap(t,-1,1,0,1);
                //---------------------------------
    t = step(1-t, Threshold);   //���2�l�����邱�Ƃŉe�͈̔͂𒲐�����B
               //float shadowAttenuation;
                   //float shadowAttenuation;
   //ShadowAttenuation = 2*ShadowAttenuation; 
    //MainLight_float(WorldPos, Direction, Color, AdditionalColor, DistAttenuation, AdditionalDistAttenuation, ShadowAttenuation);
    DistAttenuation = remap(DistAttenuation,0, 2, 0, 1);
    AdditionalDistAttenuation = remap(AdditionalDistAttenuation,0, 2, 0, 1);
   // ShadowAttenuation *= 0.01;      //shadowAtten�̓��C�g���G�ꂽ�Ƃ��ɒl���ς���Ă�H <---�@�|�C���g���C�g�͈͂ɓ���ƐF�����̂�?
    
   // ShadowAttenuation = step(t*ShadowAttenuation+DistAttenuation , Threshold); //�Ȃ������邢�ق����|1�ɂȂ��Ă�̂Ŕ��]suru
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

                //LitPassVertex���玝���Ă���
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

                //LitPassFragment���玝���Ă���
    SurfaceData surfaceData;
    InitializeStandardLitSurfaceData(input.uv, surfaceData);
    InputData inputData;
    InitializeInputData(input, surfaceData.normalTS, inputData);

    Alpha(SampleAlbedoAlpha(input.uv, TEXTURE2D_ARGS(_BaseMap, sampler_BaseMap)).a, _BaseColor, _Cutoff);
                //input.normalWS����inputData.normalWS�ɕύX
    return float4(PackNormalOctRectEncode(TransformWorldToViewDir(inputData.normalWS, true)), 0.0, 0.0);
}
