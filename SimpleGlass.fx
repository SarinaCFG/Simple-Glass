// Simple Glass by SarinaCFG

float ColorIntensity = 0.25; // Intensity of the color in glass
#define USE_EDGE // Use pass to display glass BEHIND the edge

////////////////////////////////////////////////////////////////////////////////////////////////

float3 AcsXYZ : CONTROLOBJECT < string name = "(self)"; string item = "XYZ"; > ;
float Si : CONTROLOBJECT < string name = "(self)"; string item = "Si"; > ;
float Tr : CONTROLOBJECT < string name = "(self)"; string item = "Tr"; > ;

static float RefractionSpread = AcsXYZ.x + 0.3;
static float2 NormalWarp = (0.5, 0.5) + AcsXYZ.yz;

float2 ViewportSize : VIEWPORTPIXELSIZE;
static float2 ViewportOffset = (float2(0.5, 0.5) / (1 * ViewportSize.xy));
static float2 SampleStep = (float2(1.0, 1.0) / (1 * ViewportSize.xy));

////////////////////////////////////////////////////////////////////////////////////////////////

texture SimpleGlass_Material : OFFSCREENRENDERTARGET <
							   float2 ViewPortRatio = {1.0, 1.0};
							   float4 ClearColor = {1, 1, 1, 1};
							   float ClearDepth = 1.0;
							   bool AntiAlias = true;
							   int Miplevels = 0;
							   string DefaultEffect = "self = hide;"
													  "*=Material/NoGlass.fx;";
> ;
#ifdef USE_EDGE
texture SimpleGlass_Edge : OFFSCREENRENDERTARGET <
						   float2 ViewPortRatio = {1.0, 1.0};
						   float4 ClearColor = {1, 1, 1, 1};
						   float ClearDepth = 1.0;
						   bool AntiAlias = true;
						   int Miplevels = 0;
						   string DefaultEffect = "self = hide;"
					    						  "*=EdgeControl/Edge.fx;";
> ;
#endif
// Screen
texture2D ScreenTexture : RENDERCOLORTARGET <
						  float2 ViewPortRatio = {1.0, 1.0};
						  float4 ClearColor = {1, 1, 1, 1};
						  float ClearDepth = 1.0;
						  bool AntiAlias = true;
						  string DefaultEffect = "self = hide;";
						  int Miplevels = 0;
> ;
texture2D DepthBuffer : RENDERDEPTHSTENCILTARGET <
						float2 ViewportRatio = {1, 1};
						string Format = "D24S8";
> ;
sampler2D ScreenSampler = sampler_state
{
	texture = <ScreenTexture>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = LINEAR;
	AddressU = MIRROR;
	AddressV = MIRROR;
};

// Shared
shared texture NormalTarget : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0, 1.0};
	float4 ClearColor = {1, 1, 1, 0};
	float ClearDepth = 1;
	bool AntiAlias = false;
	int Miplevels = 0;
>;
shared texture ColorTarget : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0, 1.0};
	float4 ClearColor = {1, 1, 1, 1};
	float ClearDepth = 1;
	bool AntiAlias = false;
	int Miplevels = 0;
>;
shared texture VisibilityTarget : RENDERCOLORTARGET <
	float2 ViewPortRatio = {1.0, 1.0};
	float4 ClearColor = {1, 1, 1, 1};
	float ClearDepth = 1;
	bool AntiAlias = false;
	int Miplevels = 0;
>;

shared texture2D Depth0 : RENDERDEPTHSTENCILTARGET <
    float2 ViewPortRatio = {1.0, 1.0};
    string Format = "D24S8";
>;


sampler2D NormalSampler = sampler_state
{
	texture = <NormalTarget>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
sampler2D ColorSampler = sampler_state
{
	texture = <ColorTarget>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
sampler2D VisibilitySampler = sampler_state
{
	texture = <VisibilityTarget>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
#ifdef USE_EDGE
sampler2D EdgeSampler = sampler_state
{
	texture = <SimpleGlass_Edge>;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};
#endif

////////////////////////////////////////////////////////////////////////////////////////////////

float3 Blur(sampler2D tex, float2 pos, float scale)
{
	float3 res = float3(0, 0, 0);
	int r = scale;
	if (r > 1)
		for (int i = 0; i < r; i = i + 1)
			res += tex2Dlod(tex, float4(pos + float2((r / 2 - i) / ViewportSize.x, (r / 2 - i) / ViewportSize.y), 0, log2(i))) / r;
	else
		res = tex2D(tex, pos);
	return res;
}

////////////////////////////////////////////////////////////////////////////////////////////////

struct VS_Output
{
	float4 Pos : POSITION;
	float4 TexCoord : TEXCOORD0;
	float4 p2 : TEXCOORD1;
};

VS_Output VS_Shader(float4 Pos : POSITION, float4 Tex : TEXCOORD0, uniform float level)
{
	VS_Output Out = (VS_Output)0;

	Out.Pos = Pos;
	float2 TexCoord = Tex.xy + ViewportOffset.xy * level;
	float2 Offset = SampleStep * level;
	Out.TexCoord = float4(TexCoord, Offset);
	return Out;
}

float4 PS_Final(VS_Output IN) : COLOR
{
	float4 screen = saturate(tex2D(ScreenSampler, IN.TexCoord.xy));
	float4 nr = tex2D(NormalSampler, IN.TexCoord.xy);
	float4 color = tex2D(ColorSampler, IN.TexCoord.xy);
	float4 visibility = tex2D(VisibilitySampler, IN.TexCoord.xy);
	float4 edge =float4(1,1,1,1);
	#ifdef USE_EDGE
	edge = tex2D(EdgeSampler,IN.TexCoord.xy);
	#endif
	float2 normal = nr.rg - float2(0.5, 0.5);
	float rim = nr.b;
	float2 offset = NormalWarp * normal * rim;

	float3 glass = float3(1, 1, 1);
	glass.r = Blur(ScreenSampler, IN.TexCoord.xy + offset * (1 - RefractionSpread + screen.r / 10), Si).r;
	glass.g = Blur(ScreenSampler, IN.TexCoord.xy + offset * (1 + screen.g / 10), Si).g;
	glass.b = Blur(ScreenSampler, IN.TexCoord.xy + offset * (1 + RefractionSpread + screen.b / 10), Si).b;
	glass = lerp(glass, color.rgb, rim * ColorIntensity);

	float4 result = float4(0, 0, 0, 1);
	result.rgb = lerp(screen.rgb, glass, visibility.r * Tr * edge);
	return result;
}

////////////////////////////////////////////////////////////////////////////////////////////////

float Script : STANDARDSGLOBAL <
			   string ScriptOutput = "color";
string ScriptClass = "scene";
string ScriptOrder = "postprocess";
> = 0.8;

float4 ClearColor = {0, 0, 0, 0};
float ClearDepth = 1.0;

technique SimpleGlassTech <
	string Script =
	"ClearSetColor=ClearColor;"
	"ClearSetDepth=ClearDepth;"

	"RenderColorTarget0=ScreenTexture;"
	"Clear=Color;"
	"RenderDepthStencilTarget=DepthBuffer;"
	"Clear=Depth;"

	"ScriptExternal=Color;"
	"RenderColorTarget0=;"
	"RenderDepthStencilTarget=;"
	"Pass=FinalPass;"

	"RenderColorTarget0=NormalTarget;"
	"Clear=Color;"
	"RenderColorTarget0=ColorTarget;"
	"Clear=Color;"
	"RenderColorTarget0=VisibilityTarget;"
	"Clear=Color;"

	"RenderDepthStencilTarget=Depth0;"
	"Clear=Depth;";
>
{
	pass FinalPass < string Script = "Draw=Buffer;";
	>
	{
		AlphaBlendEnable = true;
		AlphaTestEnable = true;
		VertexShader = compile vs_3_0 VS_Shader(1);
		PixelShader = compile ps_3_0 PS_Final();
	}
}