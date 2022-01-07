//////////////////////////////////
//参考 https://blog.siliconstudio.co.jp/2021/05/960/
/////////////////////


TEXTURE2D(_CameraColorTexture);
SAMPLER(sampler_CameraColorTexture);
float4 _CameraColorTexture_TexelSize;

TEXTURE2D(_CameraDepthTexture);
SAMPLER(sampler_CameraDepthTexture);

TEXTURE2D(_CameraNormalsTexture);
SAMPLER(sampler_CameraNormalsTexture);

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
	float halfScaleFloor = floor(OutlineThickness * 0.5);
	float halfScaleCeil = ceil(OutlineThickness * 0.5);
	float2 Texel = (1.0) / float2(_CameraColorTexture_TexelSize.z, _CameraColorTexture_TexelSize.w);

	float2 uvSamples = UV;
	float depthSamples[8];
    float3 normalSamples[8], colorSamples[8];
  //  float2 uvSamples[4];

    float4 colorDiag;
    float4 colorAxis;


	// 近隣のテクスチャ色をサンプリング	
    float2 uvDist = Texel* OutlineThickness;
    float centerColor = (SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy)); // Center
    colorDiag.x = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy + uvDist); // TR
    colorDiag.y = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy + uvDist * float2(-1.0f, 1.0f)); // TL
    colorDiag.z = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy - uvDist * float2(-1.0f, 1.0f)); // BR
    colorDiag.w = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy - uvDist); // BL
    colorAxis.x = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy + uvDist * float2(0.0f, 1.0f)); // T
    colorAxis.y = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy - uvDist * float2(1.0f, 0.0f)); // L
    colorAxis.z = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy + uvDist * float2(1.0f, 0.0f)); // R
    colorAxis.w = SAMPLE_DEPTH_TEXTURE(_CameraColorTexture, sampler_CameraColorTexture, uvSamples.xy - uvDist * float2(0.0f, 1.0f)); // B

	const float4 vertDiagCoeff = float4(-1.0f, -1.0f, 1.0f, 1.0f); //TR , TL , BR , BL
    const float4 horizDiagCoeff = float4(1.0f, -1.0f, 1.0f, -1.0f);
    const float4 vertAxisCoeff = float4(-2.0f, 0.0f, 0.0f, 2.0f); // T, L , R , B
    const float4 horizAxisCoeff = float4(0.0f, -2.0f, 2.0f, 0.0f);

	// Color
    float4 sobelH = colorDiag * horizDiagCoeff + colorAxis * horizAxisCoeff;
    float4 sobelV = colorDiag * vertDiagCoeff + colorAxis * vertAxisCoeff;
    float sobelX = dot(sobelH, float4(1.0f, 1.0f, 1.0f, 1.0f));
    float sobelY = dot(sobelV, float4(1.0f, 1.0f, 1.0f, 1.0f));

    float sobel = sqrt(sobelX * sobelX + sobelY * sobelY);
    float colorEdge = sobel > 1/ColorSensitivity * centerColor ? 1.0f : 0.0f;
	//float edgeColor = max(edgeDepth, max(edgeNormal, edgeColor));
	
	///float edge = edgeColor;
	float4 original = SAMPLE_TEXTURE2D(_CameraColorTexture, sampler_CameraColorTexture, uvSamples[0]);
	//Out = SAMPLE_TEXTURE2D(_OutlineMaskTexture, sampler_OutlineMaskTexture, uvSamples[0]);//((1 - edge) * original) + (edge * lerp(original, OutlineColor, OutlineColor.a));
    Out = float4(sobel, sobel, sobel, 1);
	//Out = ((1 - edgeColor) * original) + (edgeColor * lerp(original, OutlineColor, OutlineColor.a));
}