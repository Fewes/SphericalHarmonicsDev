Shader "Unlit/SHTester"
{
	Properties
	{
		_SampleCount ("Sample Count", Range(8, 1024)) = 128
		_CubemapMip ("Radiance Mip", Range(0, 7)) = 0

		[Toggle(NON_LINEAR_EVALUATION)] _NonLinearEvaluation ("Non-Linear Evaluation", Float) = 0
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma shader_feature_fragment NON_LINEAR_EVALUATION

			#include "UnityCG.cginc"
			#include "Packages/dev.fewes.sphericalharmonics/Include.hlsl"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float3 positionWS : TEXCOORD1;
				float3 centerWS : TEXCOORD2;
				float4 shData1 : TEXCOORD3;
				float4 shData2 : TEXCOORD4;
				float4 shData3 : TEXCOORD5;
			};

			float _SampleCount;
			float _CubemapMip;

			// Note that this should be 4 * PI, but because Unity skips division by PI in its BRDF functions we must also omit it here
			#define SPHERE_SOLID_ANGLE 4

			v2f vert (appdata v)
			{
				v2f o;

				o.uv = v.uv;

				// Make quad face camera
				o.centerWS = mul(UNITY_MATRIX_M, float4(0, 0, 0, 1));
				float3 normal = normalize(_WorldSpaceCameraPos - o.centerWS);
				float3 binormal = float3(0, 1, 0);
				float3 tangent = normalize(cross(normal, binormal));
				binormal = normalize(cross(tangent, normal));
				o.positionWS = o.centerWS + (tangent * (v.uv.x - 0.5) + binormal * (v.uv.y - 0.5)) * 2;
				o.vertex = mul(UNITY_MATRIX_VP, float4(o.positionWS, 1));

				SH3 sh = (SH3)0;

				// Fibonacci sphere
				const float phi = PI * (3 - sqrt(5));
				for (int i = 0; i < _SampleCount; i++)
				{
					float y = 1 - ((float)i / (_SampleCount - 1)) * 2;
					float radius = sqrt(1 - y * y);

					float theta = phi * i;

					float x = cos(theta) * radius;
					float z = sin(theta) * radius;
					float3 direction = float3(x, y, z);

					// Sample the radiance in the current iteration direction
					float3 radiance = DecodeHDR(UNITY_SAMPLE_TEXCUBE_LOD(unity_SpecCube0, direction, _CubemapMip), unity_SpecCube0_HDR);

					// Add radiance
					sh.AddRadiance(direction, radiance);
				}
				// Scale by sphere solid angle and normalize by sample count
				sh.Scale(SPHERE_SOLID_ANGLE / _SampleCount);

				// Pack 12 channel SH struct to 3 float4s
				PackSH(sh, o.shData1, o.shData2, o.shData3);

				return o;
			}

			float2 SphereIntersection(float3 rayStart, float3 rayDir, float3 sphereCenter, float sphereRadius)
			{
				rayStart -= sphereCenter;
				float a = dot(rayDir, rayDir);
				float b = 2.0 * dot(rayStart, rayDir);
				float c = dot(rayStart, rayStart) - (sphereRadius * sphereRadius);
				float d = b * b - 4 * a * c;
				if (d < 0)
				{
					return -1;
				}
				else
				{
					d = sqrt(d);
					return float2(-b - d, -b + d) / (2 * a);
				}
			}

			float4 frag (v2f i) : SV_Target
			{
				// Get sphere alpha/normal
				float3 rayStart = _WorldSpaceCameraPos;
				float3 rayDir = normalize(i.positionWS - rayStart);
				float2 t = SphereIntersection(rayStart, rayDir, i.centerWS, 0.5);
				clip(t.x);
				float3 positionWS = rayStart + rayDir * t.x;
				float3 normalWS = normalize(positionWS - i.centerWS);

				// Unpack SH data
				SH3 sh = UnpackSH(i.shData1, i.shData2, i.shData3);

#if NON_LINEAR_EVALUATION
				float3 color = sh.EvaluateNonLinear(normalWS); // Guarantees no negative values/ringing. More expensive.
#else
				float3 color = sh.Evaluate(normalWS); // More contrast. Faster.
#endif

				return float4(color, 1);
			}
			ENDCG
		}
	}
}
