Shader "Unlit/SobelFilter"
{
	Properties 
	{
	    [HideInInspector]_MainTex ("Base (RGB)", 2D) = "white" {}
		_Delta ("Line Thickness", Range(0.0005, 0.0025)) = 0.001
		_OutlineThreshold("Outline Threshold",Float) = 1			//mokutsuno add
		[Toggle(RAW_OUTLINE)]_Raw ("Outline Only", Float) = 0
		[Toggle(POSTERIZE)]_Poseterize ("Posterize", Float) = 0
		_PosterizationCount ("Count", int) = 8
	}
	SubShader 
	{
		Tags { "RenderType"="Opaque" }
		LOD 200
		
		Pass
		{
            HLSLPROGRAM
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/SurfaceInput.hlsl"
            #include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Color.hlsl"
            
            #pragma shader_feature RAW_OUTLINE
            #pragma shader_feature POSTERIZE
            
            TEXTURE2D(_CameraDepthTexture);
            SAMPLER(sampler_CameraDepthTexture);
			TEXTURE2D(_CameraOpaqueTexture);
			SAMPLER(sampler_CameraOpaqueTexture);
			TEXTURE2D(_MainTex);
			SAMPLER(sampler_MainTex);
//#ifndef RAW_OUTLINE
 //           TEXTURE2D(_MainTex);
 //           SAMPLER(sampler_MainTex);
//#endif

            float _Delta;
            int _PosterizationCount;
			float _OutlineThreshold;		//mokutsuno add
            struct Attributes
            {
                float4 positionOS       : POSITION;
                float2 uv               : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv        : TEXCOORD0;
                float4 vertex : SV_POSITION;
                UNITY_VERTEX_OUTPUT_STEREO
            };
            
            float SampleDepth(float2 uv)
            {
#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
                return SAMPLE_TEXTURE2D_ARRAY(_CameraDepthTexture, sampler_CameraDepthTexture, uv, unity_StereoEyeIndex).r;
#else
                return SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, sampler_CameraDepthTexture, uv);
#endif
            }
			float SampleOpaque(float2 uv)
			{
#if defined(UNITY_STEREO_INSTANCING_ENABLED) || defined(UNITY_STEREO_MULTIVIEW_ENABLED)
				return SAMPLE_TEXTURE2D_ARRAY(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv, unity_StereoEyeIndex).r;
#else
				return SAMPLE_DEPTH_TEXTURE(_CameraOpaqueTexture, sampler_CameraOpaqueTexture, uv);
#endif
			}
            float sobel (float2 uv) 
            {
                float2 delta = float2(_Delta, _Delta);
               /*
                float hr = 0;
                float vt = 0;

				hr += SampleDepth(uv + float2(-1.0, -1.0) * delta) *  1.0;
                hr += SampleDepth(uv + float2( 1.0, -1.0) * delta) * -1.0;
                hr += SampleDepth(uv + float2(-1.0,  0.0) * delta) *  2.0;
                hr += SampleDepth(uv + float2( 1.0,  0.0) * delta) * -2.0;
                hr += SampleDepth(uv + float2(-1.0,  1.0) * delta) *  1.0;
                hr += SampleDepth(uv + float2( 1.0,  1.0) * delta) * -1.0;
                
                vt += SampleDepth(uv + float2(-1.0, -1.0) * delta) *  1.0;
                vt += SampleDepth(uv + float2( 0.0, -1.0) * delta) *  2.0;
                vt += SampleDepth(uv + float2( 1.0, -1.0) * delta) *  1.0;
                vt += SampleDepth(uv + float2(-1.0,  1.0) * delta) * -1.0;
                vt += SampleDepth(uv + float2( 0.0,  1.0) * delta) * -2.0;
                vt += SampleDepth(uv + float2( 1.0,  1.0) * delta) * -1.0;
				*/


				//  OUTLINE FROM DEPTH --------------------------
				// 近隣のテクスチャ色をサンプリング
				float diffU =1  * _Delta;
				float diffV = 1 * _Delta;
				half3 col00 = SampleDepth(uv + half2(-diffU, -diffV));
				half3 col01 = SampleDepth(uv + half2(-diffU, 0.0));
				half3 col02 = SampleDepth(uv + half2(-diffU, diffV));
				half3 col10 = SampleDepth(uv + half2(0.0, -diffV));
				half3 col12 = SampleDepth(uv + half2(0.0, diffV));
				half3 col20 = SampleDepth(uv + half2(diffU, -diffV));
				half3 col21 = SampleDepth(uv + half2(diffU, 0.0));
				half3 col22 = SampleDepth(uv + half2(diffU, diffV));

				// 水平方向のコンボリューション行列適用後の色を求める
				half3 horizontalColor = 0;
				horizontalColor += col00 * -1.0;
				horizontalColor += col01 * -2.0;
				horizontalColor += col02 * -1.0;
				horizontalColor += col20;
				horizontalColor += col21 * 2.0;
				horizontalColor += col22;

				// 垂直方向のコンボリューション行列適用後の色を求める
				half3 verticalColor = 0;
				verticalColor += col00;
				verticalColor += col10 * 2.0;
				verticalColor += col20;
				verticalColor += col02 * -1.0;
				verticalColor += col12 * -2.0;
				verticalColor += col22 * -1.0;

				// この値が大きく正の方向を表す部分がアウトライン
				// ※1
				half3 outlineValue = horizontalColor * horizontalColor + verticalColor * verticalColor;
				half edge = outlineValue.x - _OutlineThreshold;
				//  OUTLINE FROM DEPTH END --------------------------
				float diffU_c = 1 * _Delta;
				float diffV_c = 1 * _Delta;
				half3 col00_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(-diffU_c, -diffV_c)));
				half3 col01_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(-diffU_c, 0.0)));
				half3 col02_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(-diffU_c, diffV_c)));
				half3 col10_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(0.0, -diffV_c)));
				half3 col12_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(0.0, diffV_c)));
				half3 col20_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(diffU_c, -diffV_c)));
				half3 col21_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(diffU_c, 0.0)));
				half3 col22_c = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, (uv + half2(diffU_c, diffV_c)));

				// 水平方向のコンボリューション行列適用後の色を求める
				half3 horizontalColor_c = 0;
				horizontalColor_c += col00_c * -1.0;
				horizontalColor_c += col01_c * -2.0;
				horizontalColor_c += col02_c * -1.0;
				horizontalColor_c += col20_c;
				horizontalColor_c += col21_c * 2.0;
				horizontalColor_c += col22_c;

				// 垂直方向のコンボリューション行列適用後の色を求める
				half3 verticalColor_c = 0;
				verticalColor_c += col00_c;
				verticalColor_c += col10_c * 2.0;
				verticalColor_c += col20_c;
				verticalColor_c += col02_c * -1.0;
				verticalColor_c += col12_c * -2.0;
				verticalColor_c += col22_c * -1.0;

				// この値が大きく正の方向を表す部分がアウトライン
				// ※1
				half3 outlineValue_c = horizontalColor_c * horizontalColor_c + verticalColor_c * verticalColor_c;
				half edge_c_r = outlineValue_c.x - _OutlineThreshold;
				half edge_c_g = outlineValue_c.y - _OutlineThreshold;
				half edge_c_b = outlineValue_c.z - _OutlineThreshold;
				half edge_c = edge_c_r+ edge_c_g + edge_c_b;
				return edge+edge_c;
            }
            
            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                output.vertex = vertexInput.positionCS;
                output.uv = input.uv;
                
                return output;
            }
            
            half4 frag (Varyings input) : SV_Target 
            {
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);
                
                float s = pow(1 - saturate(sobel(input.uv)),50);
#ifdef RAW_OUTLINE
                return half4(s.xxx, 1);
#else
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
#ifdef POSTERIZE
                col = pow(col, 0.4545);
                float3 c = RgbToHsv(col);
                c.z = round(c.z * _PosterizationCount) / _PosterizationCount;
                col = float4(HsvToRgb(c), col.a);
                col = pow(col, 2.2);
#endif
                return col * s;
#endif
            }
            
			#pragma vertex vert
			#pragma fragment frag
			
			ENDHLSL
		}
	} 
	FallBack "Diffuse"
}
