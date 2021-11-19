// This shader fills the mesh shape with a color predefined in the code.
Shader "Custom/Distortion"
{
    // The properties block of the Unity shader. In this example this block is empty
    // because the output color is predefined in the fragment shader code.
    Properties
    {
        _Intensity("Intensity", Range(0, 1)) = 0
        _Speed("Speed", Range(0, 10)) = 1
        _NoiseScale("NoiseScale", Range(0.5, 10)) = 1
        _NoiseOffset("NoiseOffset", Range(0, 1)) = 0.5
        [NoScaleOffset]
        _Mask("Mask", 2D) = "white" {}
        [NoScaleOffset]
        _NoiseMap("NoiseMap", 2D) = "black" {}
        [Toggle]
        _Debug("Debug", Float) = 0
    }

    // The SubShader block containing the Shader code. 
    SubShader
    {
        // SubShader Tags define when and under which conditions a SubShader block or
        // a pass is executed.
        Tags { 
            "RenderType" = "Transparent"
            "RenderPipeline" = "UniversalRenderPipeline"
            "Queue" = "Transparent"
            "LightMode" = "Distortion"
            }

        Pass
        {
            Cull off
            ZWrite off
            ZTest LEqual
            // The HLSL code block. Unity SRP uses the HLSL language.
            HLSLPROGRAM
            // This line defines the name of the vertex shader. 
            #pragma vertex vert
            // This line defines the name of the fragment shader. 
            #pragma fragment frag
            #pragma target 2.5

            // The Core.hlsl file contains definitions of frequently used HLSL
            // macros and functions, and also contains #include references to other
            // HLSL files (for example, Common.hlsl, SpaceTransforms.hlsl, etc.).
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityInput.hlsl"

            // The structure definition defines which variables it contains.
            // This example uses the Attributes structure as an input structure in
            // the vertex shader.
            struct Attributes
            {
                // The positionOS variable contains the vertex positions in object
                // space.
                float4 positionOS   : POSITION;
                float2 uv: TEXCOORD0;
            };

            struct Varyings
            {
                // The positions in this struct must have the SV_POSITION semantic.
                float4 positionHCS  : SV_POSITION;
                float2 uv: TEXCOORD0;
            };

            sampler2D _NoiseMap;
            sampler2D _Mask;
            sampler2D _CameraTransparentTexture;
            CBUFFER_START(UnityPerMaterial)
            half _Speed;
            float _NoiseScale;
            half _Intensity;
            half _NoiseOffset;
            half _Debug;
            CBUFFER_END

            // The vertex shader definition with properties defined in the Varyings 
            // structure. The type of the vert function must match the type (struct)
            // that it returns.
            Varyings vert(Attributes IN)
            {
                Varyings OUT;

                // billboard mesh towards camera
                float3 viewDirctionOS = TransformWorldToObject(_WorldSpaceCameraPos);
                float3 normalDirOS = normalize(viewDirctionOS);
                float3 upDir = abs(normalDirOS.y) > 0.999 ? float3(0, 0, 1) : float3(0, 1, 0);
                float3 rightDir = normalize(cross(upDir, normalDirOS));
                upDir = normalize(cross(normalDirOS, rightDir));
                float3 centerOffset = IN.positionOS.xyz;
                float3 localPos = mul(centerOffset, float3x3(rightDir, upDir, normalDirOS));
                
                OUT.positionHCS = TransformObjectToHClip(localPos.xyz);
                OUT.uv = IN.uv;
                return OUT;
            }

            // The fragment shader definition.            
            half4 frag(Varyings IN) : SV_Target
            {
                float2 noiseUV = IN.uv;
                noiseUV *= _NoiseScale;
                half4 noise = tex2D(_NoiseMap, noiseUV  + float2(0.0, -_Speed * _Time.x));
                noise = noise - _NoiseOffset;

                const half4 mask = saturate(tex2D(_Mask, IN.uv));
                const half4 maskNoise = mask * noise;

                float2 screenUV = (IN.positionHCS.xy / _ScreenParams.xy);
                const float2 screenUVWithNoise = maskNoise.xy + screenUV;
                screenUV = lerp(screenUV, screenUVWithNoise, _Intensity);
                
                half4 cameraColor = tex2D(_CameraTransparentTexture, screenUV);
               
                return cameraColor;
            }
            ENDHLSL
        }
    }
}