//https://nemlog.nem.social/blog/36759
Shader "URP_BD/Hatching"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
        _ShadowColor("Shadow Color",Color) = (1,1,1,1)
        _ClampThreshold("Clamp Threshold",Range(0.0,5.0)) = 0.5
    }
        SubShader
    {
        Tags {
            "RenderType" = "Opaque"
            "RenderPipeline" = "UniversalPipeline"
                        "UniversalMaterialType" = "Lit"
                    "Queue" = "AlphaTest"
        }
        LOD 100
            // Render State
Cull Back
Blend One Zero
ZTest LEqual
ZWrite On
            PASS{
                Name "Lighting"
                Tags{"LightMode" = "UniversalForward"}
            HLSLPROGRAM

            // Pragmas
            #define _ADDITIONAL_LIGHTS 1        //�d���H�@�������C�g���g��
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag


          //  #include "Assets/LookDev/Materials/Toon/GetLighting.hlsl"
            #include "Assets/LookDev/Shaders/BDLit.hlsl"
         //   #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
       //     #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"


                TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _ShadowColor;
            float _ClampThreshold;
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
            CBUFFER_END



            

            BDVaryings vert(BDAttributes input)
            {
                BDVaryings output = (BDVaryings)0;
                VertexPositionInputs vertex = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertex.positionCS;
                output.positionWS = vertex.positionWS;
                VertexNormalInputs normal = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normal.normalWS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            float4 frag(BDVaryings input) : SV_Target
            {
                // �J�����ƃI�u�W�F�N�g�̋���(����)���擾
                // _WorldSpaceCameraPos�F��`�ς̒l�@���[���h���W�n�̃J�����̈ʒu
               float cameraToObjLength = length(_WorldSpaceCameraPos - input.positionWS);
               float3 Direction;
               float3 Color;
               float ShadowAttenuation;
               float LitShadAttenuation;
               GetToonLit(input.normalWS,input.positionWS, Direction, 0.5,Color, ShadowAttenuation, LitShadAttenuation);
               float4 albedoColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv); //tex2d
               float4 shadowTexColor = albedoColor*_ShadowColor;
               float4 output = lerp(albedoColor, shadowTexColor, LitShadAttenuation);
              // output = LitShadAttenuation;
               // MainLight_float(input.positionWS, Direction, Color, Attenuation);    //MainLight_float(float3 WorldPos, out half3 Direction, out half3 Color, out half Attenuation)
               return  output;
           //return tex2D(_MainTex, input.uv) * mask;
       }
       ENDHLSL

           }
            // This pass is used when drawing to a _CameraNormalsTexture texture
           
Pass
{
Name"DepthNormals"
            Tags
{"LightMode" = "DepthNormals"
}

ZWrite On

Cull[_Cull]

HLSLPROGRAM
            #pragma exclude_renderers gles gles3 glcore
            #pragma target 4.5

            #pragma vertex DepthNormalsVertex
            #pragma fragment DepthNormalsFragment

// -------------------------------------
// Material Keywords
#pragma shader_feature_local _NORMALMAP
#pragma shader_feature_local_fragment _ALPHATEST_ON
#pragma shader_feature_local_fragment _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A

//--------------------------------------
// GPU Instancing
#pragma multi_compile_instancing
#pragma multi_compile _ DOTS_INSTANCING_ON
#define _NORMALMAP
            #include "Assets/LookDev/Shaders/BDLit.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
#include "Packages/com.unity.render-pipelines.universal/Shaders/LitForwardPass.hlsl"
ENDHLSL
}


Pass
        {
            Name "Hatching"
                Tags{"LightMode" = "Hatching"}

            HLSLPROGRAM
            #pragma prefer_hlslcc gles
            #pragma exclude_renderers d3d11_9x
            #pragma target 2.0

            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            CBUFFER_START(UnityPerMaterial)
            sampler2D _MainTex;
            float4 _MainTex_ST;

            float _ClampThreshold;
            CBUFFER_END




            struct Attributes2
            {
                float4 positionOS : POSITION;
                float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct Varyings2
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD8;      //POSITION���ƃG���[�N����̂�TEXCOORD�Ŏb��Ώ�
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };
            float remap(float value, float inputMin, float inputMax, float outputMin, float outputMax)
            {
                return (value - inputMin) * ((outputMax - outputMin) / (inputMax - inputMin)) + outputMin;
            }

            Varyings2 vert(Attributes2 input)
            {
                Varyings2 output = (Varyings2)0;
                VertexPositionInputs vertex = GetVertexPositionInputs(input.positionOS.xyz);
                output.positionCS = vertex.positionCS;
                output.positionWS = vertex.positionWS;
                VertexNormalInputs normal = GetVertexNormalInputs(input.normalOS);
                output.normalWS = normal.normalWS;
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            float4 frag(Varyings2 input) : SV_Target
            {
                    Light mainLight = GetMainLight();
    float strength = dot(mainLight.direction, input.normalWS);
    float oneminusStrength = -1 * (strength - 1);
               //

               // �n�b�`���O����
                //

                // �J�����ƃI�u�W�F�N�g�̋���(����)���擾
                // _WorldSpaceCameraPos�F��`�ς̒l�@���[���h���W�n�̃J�����̈ʒu
               float cameraToObjLength = length(_WorldSpaceCameraPos - input.positionWS);
               float offset = 1;
                
               float patternNum  =0.02;
                //float remappedStrength = Remap01(strength, _ClampThreshold,0);
                float4 lightColor = float4(mainLight.color, 1);

                float hatchingLine = fmod(input.uv.x,patternNum);
                hatchingLine = remap(hatchingLine, 0, patternNum, 0, 1);

                float clampCTOL = clamp(cameraToObjLength, 0, 10);
                //float remap = Remap01(strength * hatchingLine, _ClampThreshold, 0);
                float mask = step(oneminusStrength * hatchingLine, 1 / (clampCTOL +offset)+_ClampThreshold );
                    //float mask =  hatchingLine;
                return  mask;
                //return tex2D(_MainTex, input.uv) * mask;
            }
            ENDHLSL
        }
    }

}