Shader "BD/NormalTest"
{
    Properties
    {
        _BaseMap("Base Map", 2D) = "white" {}
        _BaseColor("Base Color", Color) = (1, 1, 1, 1)
    }

        SubShader
        {
            Tags
            {
                "RenderType" = "Opaque"
                "RenderPipeline" = "UniversalPipeline"
                "IgnoreProjector" = "True"
                "Queue" = "Geometry"
            }

            Pass
            {
                // �p�X�̗p�r��LightMode�Ŏw��
                // ���ɂ�ShadowCaster��DepthOnly�Ȃǂ�����
                Tags
                {
                    "LightMode" = "UniversalForward"
                }

            // URP�̏ꍇ��CGPROGRAM�ł͂Ȃ�HLSLPROGRAM���g��
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            // Core.hlsl���C���N���[�h����
            // �悭�g����HLSL�̃}�N����֐�����`����Ă���
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct Attributes
            {
            // OS��Object Space�̗�
            // �ϐ����͉��ł�������URP�ł͍��W�̕ϐ����ɂ��̂悤��Suffix��t����̂���ʓI
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionHCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };

        sampler2D _BaseMap;

        // SRP Batcher�ɂ��o�b�`���O�������������ꍇ�ɂ�CBUFFER�u���b�N���ɕϐ����L�q����
        // �ڂ����� �� https://light11.hatenadiary.com/entry/2021/07/15/201733
        CBUFFER_START(UnityPerMaterial)
        float4 _BaseMap_ST;
        half4 _BaseColor;
        CBUFFER_END

        Varyings vert(Attributes IN)
        {
            Varyings OUT;
            // ���p�C�v���C���ł�UnityObjectToClipPos�������̂�URP�ł�TransformObjectToHClip��
            OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
            OUT.uv = TRANSFORM_TEX(IN.uv, _BaseMap);
            return OUT;
        }

        // HLSLPROGRAM�̏ꍇ�Afixed4�͎g���Ȃ�
        half4 frag(Varyings IN) : SV_Target
        {
            return tex2D(_BaseMap, IN.uv) * _BaseColor;
        }
        ENDHLSL
    }

            /**  normal�������Ɠ���������玝���Đ���������
         Name "NormalOnly"
        Tags { "LightMode" = "NormalOnly" }

                HLSLPROGRAM
                 //       #pragma vertex NormalsPassVertex
                #pragma fragment NormalsPassFragment
                #include "Packages/com.unity.render-pipelines.universal/Shaders/LitInput.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/Shaders/PostProcessing/Common.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
                #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareNormalsTexture.hlsl"

            float4x4 _ViewToWorld;
                 half4 NormalsPassFragment(Varyings i) : SV_Target
             {

                //float4 mainColor = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv);

                float depth = SampleSceneDepth(i.uv);
                float3 normal = SampleSceneNormals(i.uv);

                depth = Linear01Depth(depth, _ZBufferParams);
                //View��Ԃ���World��Ԃɕϊ�
                normal = mul((float3x3)_ViewToWorld, normal);

                half4 color = float4(normal,depth);

                return color;
            }
                 ENDHLSL
        }**/
                 
        }
}
