﻿Shader "Hidden/OutlineMask"
{
		Properties{
			_MainTex("", 2D) = "white" {}
			_Cutoff("", Float) = 0.5
			_Color("", Color) = (1,1,1,1)
		}

			SubShader{
				Tags { "RenderType" = "Opaque" }
				Pass {
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#include "UnityCG.cginc"
			struct v2f {
				float4 pos : SV_POSITION;
				float4 nz : TEXCOORD0;
				UNITY_VERTEX_OUTPUT_STEREO
			};
			v2f vert(appdata_base v) {
				v2f o;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				o.pos = UnityObjectToClipPos(v.vertex);
				o.nz.xyz = COMPUTE_VIEW_NORMAL;
				o.nz.w = COMPUTE_DEPTH_01;
				return o;
			}
			fixed4 frag(v2f i) : SV_Target {
				return fixed4(1, 1,0,1);
			}
			ENDCG
				}
			}

			}