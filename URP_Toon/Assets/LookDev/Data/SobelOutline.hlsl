TEXTURE2D(_CameraColorTexture);
SAMPLER(sampler_CameraColorTexture);
float4 _CameraColorTexture_TexelSize;

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

TEXTURE2D(_CameraDepthNormalsTexture);
SAMPLER(sampler_CameraDepthNormalsTexture);

TEXTURE2D(_OutlineMaskTexture);
SAMPLER(sampler_OutlineMaskTexture);
uniform float hCoef[8] = {
	1.0, -1.0, -2.0,
		-1.0, 0.0, 0.0,
		2.0,1.0};
uniform float vCoef[8] = {
	1.0, 0.0, -1.0,
		2.0, -2.0, 0.0,
		0.0, -1.0 };

float3 DecodeNormal(float4 enc)
{
	float kScale = 1.7777;
	float3 nn = enc.xyz*float3(2 * kScale, 2 * kScale, 0) + float3(-kScale, -kScale, 1);
	float g = 2.0 / dot(nn.xyz, nn.xyz);
	float3 n;
	n.xy = g * nn.xy;
	n.z = g - 1;
	return n;
}

void Outline_float(float2 UV, float OutlineThickness, float DepthSensitivity, float NormalsSensitivity, float ColorSensitivity, float4 OutlineColor, out float4 Out)
{
	//float halfScaleFloor = floor(OutlineThickness * 0.5);
	//float halfScaleCeil = ceil(OutlineThickness * 0.5);
	//float2 Texel = (1.0) / float2(_CameraColorTexture_TexelSize.z, _CameraColorTexture_TexelSize.w);

	float2 uvSamples[8];
	float depthSamples[8];
	float3 normalSamples[8], colorSamples[8];


	// 近隣のテクスチャ色をサンプリング
	float diffU = _CameraColorTexture_TexelSize.x * OutlineThickness;
	float diffV = _CameraColorTexture_TexelSize.y * OutlineThickness;

	uvSamples[0] = UV  + half2(-diffU, -diffV);			//(-1.0,-1.0)
	uvSamples[1] = UV + half2(-diffU, 0.0);	//(0.0,-1.0)
	uvSamples[2] = UV + half2(-diffU, diffV);			//(1.0,-1.0)
	uvSamples[3] = UV + half2(0.0, -diffV); //(-1.0,0.0)
	uvSamples[4] = UV + half2(0.0, diffV); //(0.0,0.0)
	uvSamples[5] = UV + half2(diffU, -diffV);	//(1.0,0.0)
	uvSamples[6] = UV + half2(diffU, 0.0);			//(-1.0,1.0)
	uvSamples[7] = UV + half2(diffU, diffV);	//(0.0,1.0)

	float depthHColor = 0;
	float depthVColor = 0;
	float3 normalHColor = float3(0, 0, 0);
	float3 normalVColor = float3(0, 0, 0);
	float3 colorHColor = float3(0, 0, 0);
	float3 colorVColor = float3(0, 0, 0);


	for (int i = 0; i < 8; i++)
	{
		/*
		depthVColor += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[i]).r * vCoef[i];
		normalVColor += DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvSamples[i])) * vCoef[i];
		colorVColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[i]) * vCoef[i];
		
		depthHColor += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[i]).r * hCoef[i];
		normalHColor += DecodeNormal(SAMPLE_TEXTURE2D(_CameraDepthNormalsTexture, sampler_CameraDepthNormalsTexture, uvSamples[i])) * hCoef[i];
		colorHColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[i]) * hCoef[i];
		*/

	}

	// https://light11.hatenadiary.com/entry/2018/05/13/161104

	// 水平方向のコンボリューション行列適用後の色を求める
	half3 horizontalColorDepth = 0;
	horizontalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[0]).r * -1.0;
	horizontalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[1]).r * -2.0;
	horizontalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[2]).r * -1.0;
	horizontalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[5]).r;
	horizontalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[6]).r * 2.0;
	horizontalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[7]).r;

	// 垂直方向のコンボリューション行列適用後の色を求める
	half3 verticalColorDepth = 0;
	verticalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[0]).r;
	verticalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[3]).r * 2.0;
	verticalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[6]).r;
	verticalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[2]).r * -1.0;
	verticalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[5]).r * -2.0;
	verticalColorDepth += SAMPLE_TEXTURE2D(_CameraDepthTexture, sampler_CameraDepthTexture, uvSamples[7]).r * -1.0;


	// 水平方向のコンボリューション行列適用後の色を求める
	half3 horizontalColor = 0;
	horizontalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[0]) * -1.0;
	horizontalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[1]) * -1.0;
	horizontalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[2]) * -1.0;
	horizontalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[5]);
	horizontalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[6]) * 1.0;
	horizontalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[7]);

	// 垂直方向のコンボリューション行列適用後の色を求める
	half3 verticalColor = 0;
	verticalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[0]);
	verticalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[3]) * 1.0;
	verticalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[6]);
	verticalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[2]) * -1.0;
	verticalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[5]) * -1.0;
	verticalColor += SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[7]) * -1.0;


	// Depth

	//float edgeDepth = sqrt(depthHColor * depthHColor + depthVColor * depthVColor) ;
	float depthThreshold = (1 / DepthSensitivity) ;
	float outlineValue = sqrt(horizontalColorDepth * horizontalColorDepth + verticalColorDepth * verticalColorDepth)*100;
	float edgeDepth = outlineValue;
	edgeDepth = edgeDepth > depthThreshold ? 1 : 0;
	/*
	// Normals
	float3 normalFiniteDifference0 = normalSamples[1] - normalSamples[0];
	float3 normalFiniteDifference1 = normalSamples[3] - normalSamples[2];
	float edgeNormal = sqrt(dot(normalFiniteDifference0, normalFiniteDifference0) + dot(normalFiniteDifference1, normalFiniteDifference1));
	edgeNormal = edgeNormal > (1 / NormalsSensitivity) ? 1 : 0;

	// Color
	float3 colorFiniteDifference0 = colorSamples[1] - colorSamples[0];
	float3 colorFiniteDifference1 = colorSamples[3] - colorSamples[2];
	float edgeColor = sqrt(dot(colorFiniteDifference0, colorFiniteDifference0) + dot(colorFiniteDifference1, colorFiniteDifference1));
	
	*/
	half3 edgeColorRGB = horizontalColor * horizontalColor + verticalColor * verticalColor;
	float edgeColor = max(edgeColorRGB.r, max(edgeColorRGB.g, edgeColorRGB.b));
	edgeColor = edgeColor > (1 / ColorSensitivity) ? 1 : 0;

	//float edgeColor = max(edgeDepth, max(edgeNormal, edgeColor));
	
	///float edge = edgeColor;
	float4 original = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[0]);
	//Out = SAMPLE_TEXTURE2D(_OutlineMaskTexture, sampler_OutlineMaskTexture, uvSamples[0]);//((1 - edge) * original) + (edge * lerp(original, OutlineColor, OutlineColor.a));
	//Out =float4(edgeColor, edgeColor, edgeColor,1);
	Out = ((1 - edgeColor) * original) + (edgeColor * lerp(original, OutlineColor, OutlineColor.a));
}