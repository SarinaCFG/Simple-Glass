float4x4 WorldViewProjMatrix      : WORLDVIEWPROJECTION;

struct OutVS
{
	float4 Pos			: POSITION;
};

OutVS Stealth_VS(float4 Pos : POSITION,float3 Normal : NORMAL)
{
	OutVS Out;
    Out.Pos 	= mul( Pos, WorldViewProjMatrix );
    return Out;
}

float4 Stealth_PS(OutVS IN) : COLOR
{
    return float4(0,0,0,0);
}

technique MainPass_SS  < string MMDPass = "object_ss"; > {
    pass DrawObject {
        AlphaBlendEnable = true;
		AlphaTestEnable = false;
        VertexShader = compile vs_2_0 Stealth_VS();
        PixelShader  = compile ps_2_0 Stealth_PS();
    }
}
