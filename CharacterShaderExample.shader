Shader "Character Project/Character Shader Example"
{
    Properties
    {
        [Header(Textures)]
        _MainTex("Base Color",2D)="white"{} //RGB:Color A:Opacity
        _NormalMap("Normal Map",2D)="bump"{}
        _Metallicity("Metalness Map",2D)="black"{}
        _SpecMap("Specular Map",2D)="black"{}//R:SpecInt G:RimInt B:TintMask A:SpecPow
        _EmissionMask("Emission Mask",2D)="black"{}
        _CubeMap("Cube Map",Cube)="_SkyBox"{}
        _FresnelRamp("Fresnel Ramp",2D)="black"{}
        _DiffuseRamp("Diffuse Ramp",2D)="gray"{}
        
        [Header(Diffuse)]
        _Color("Main Color",Color)=(1.0,1.0,1.0,1.0)
        _LightCol("Light Color",Color)=(1.0,1.0,1.0,1.0)
        _Brightness("The Brightness Of Base Color",Float)=1
        _Saturation("The Saturation Of Base Color",Float)=1
        _Contrast("The Contrast Of Base Color",Float)=1
        _EnvDiffVal("Environment Diffuse Value",Float)=1
        _EnvUpCol("Environment Up Color",Color)=(1.0,1.0,1.0,1.0)
        _EnvSidedCol("Environment Sided Color",Color)=(0.5,0.5,0.5,1.0)
        _EnvDownCol("Environment Down Color",Color)=(0,0,0,1.0)
        
        [Header(Specular)]
        _SpecVal("Specular Value",Float)=1
        _SpecPow("Gloss",Range(8,256))=20
        _EnvSpecVal("Environment Specular Value",Float)=1
        
        [Header(Emission)]
        _EmitCol("Emission Color",Color)=(1.0,1.0,1.0,1.0)
        _EmitVal("Emission Val",Float)=1
        _RimCol("Rim Color",Color)=(1.0,1.0,1.0)
        _RimVal("Rim Value",Float)=1
        
        _CullOff("Cut Off",Float)=1
    }
    SubShader
    {
        Tags {"RenderType"="Opaque"}
        Pass
        {
            Tags {"LightMode"="ForwardBase"}
            
            Cull Off
            
            CGPROGRAM

            #pragma multi_compile_fwdBase_fullshadows
            #pragma vertex vert;
            #pragma fragment frag;
            #pragma target 3.0

            #include "Lighting.cginc"
            #include "AutoLight.cginc"
            #include "UnityCG.cginc"

            sampler2D _MainTex;
            half4 _MainTex_ST;
            sampler2D _NormalMap;
            half4 _NormalMap_ST;
            sampler2D _Metallicity;
            sampler2D _SpecMap;
            sampler2D _EmissionMask;
            samplerCUBE _CubeMap;
            sampler2D _FresnelRamp;
            sampler2D _DiffuseRamp;
            
            fixed4 _LightCol;  
            float _Brightness;
            float _Saturation;
            float _Contrast;
            float _EnvDiffVal;
            fixed4 _EnvUpCol;
            fixed4 _EnvSidedCol;
            fixed4 _EnvDownCol;

            float _SpecPow;
            float _SpecVal;
            float _EnvSpecVal;

            float _EmitVal;
            fixed4 _EmitCol;
            fixed4 _RimCol;
            float _RimVal;

            float _CullOff;
            
            struct a2v
            {
                float4 vertex:POSITION;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
                half4 texcoord:TEXCOORD0;
            };

            struct v2f
            {
                float4 pos:SV_POSITION;
                half4 uv1:TEXCOORD0;
                half4 uv2:TEXCOORD1;
                half4 TtoW0:TEXCOORD2;
                half4 TtoW1:TEXCOORD3;
                half4 TtoW2:TEXCOORD4;
                LIGHTING_COORDS(5,6)
            };

            v2f vert(a2v v)
            {
                v2f o;
                o.pos=UnityObjectToClipPos(v.vertex);
                o.uv1.xy=TRANSFORM_TEX(v.texcoord.xy,_MainTex);
                o.uv1.zw=TRANSFORM_TEX(v.texcoord.xy,_NormalMap);
                o.uv2=v.texcoord;
                float3 worldNormal=UnityObjectToWorldNormal(v.normal);
                float3 worldTangent=UnityObjectToWorldDir(v.tangent.xyz);
                float3 worldPos=mul(unity_ObjectToWorld,v.vertex);
                float3 worldBinormal=cross(worldNormal,worldTangent)*v.tangent.w;
                o.TtoW0=half4(worldTangent.x,worldBinormal.x,worldNormal.x,worldPos.x);
                o.TtoW1=half4(worldTangent.y,worldBinormal.y,worldNormal.y,worldPos.y);
                o.TtoW2=half4(worldTangent.z,worldBinormal.z,worldNormal.z,worldPos.z);
                TRANSFER_VERTEX_TO_FRAGMENT(o)
                return o;
            }

            fixed4 ApplyColor(fixed3 c)
            {
                //Apply Brightness
                fixed3 finalColor =c.rgb*_Brightness;
                //Apply Saturation
                fixed luminance=0.2125*c.r+0.7154*c.g+0.0721*c.b;
                fixed3 luminanceColor=fixed3(luminance,luminance,luminance);
                finalColor=lerp(luminanceColor,finalColor,_Saturation);
                //Apply Contrast
                fixed3 avgColor=fixed3(0.5,0.5,0.5);
                finalColor=lerp(avgColor,finalColor,_Contrast);
                return fixed4(finalColor,1.0);
            }

            fixed4 EnvCol(half3 normal)
            {
                half upMask=max(0,normal.g);
                half downMask=max(0,-normal.g);
                half sidedMask=1-upMask-downMask;
                fixed4 envCol=upMask*_EnvUpCol+sidedMask*_EnvSidedCol+downMask*_EnvDownCol;
                return envCol;
            }

            fixed4 frag(v2f i):SV_Target
            {
                half3 worldPos=half3(i.TtoW0.w,i.TtoW1.w,i.TtoW2.w);
                half3 bump=UnpackNormal(tex2D(_NormalMap,i.uv1.zw));
                half3 worldNormal=normalize(half3(dot(i.TtoW0.xyz,bump),
                    dot(i.TtoW1.xyz,bump),dot(i.TtoW2.xyz,bump)));
                half3 worldLightDir=normalize(UnityWorldSpaceLightDir(worldPos));
                half3 worldViewDir=normalize(UnityWorldSpaceViewDir(worldPos));
                half3 worldViewReflectDir=reflect(-worldViewDir,worldNormal);
                half3 worldLightReflectDir=reflect(-worldLightDir,worldNormal);
                half3 halfDir=normalize(worldLightDir+worldViewDir);

                fixed3 baseCol=tex2D(_MainTex,i.uv1.xy).rgb;
                float opacity=tex2D(_MainTex,i.uv1.xy).a;
                fixed3 metalness=tex2D(_Metallicity,i.uv2.xy).rgb;
                float specInt=tex2D(_SpecMap,i.uv2.xy).r;
                float rimInt=tex2D(_SpecMap,i.uv2.xy).g;
                float tintMask=tex2D(_SpecMap,i.uv2.xy).b;
                float specPow=tex2D(_SpecMap,i.uv2.xy).a;
                fixed3 emissionInt=tex2D(_EmissionMask,i.uv2.xy).rgb;
                fixed3 envCube=texCUBE(_CubeMap,worldViewReflectDir).rgb;
                fixed3 fresnelRamp=tex2D(_FresnelRamp,dot(worldNormal,worldViewDir)).rgb;
                half shadow=LIGHT_ATTENUATION(i);

                clip(opacity-_CullOff);

                //LightMode->DirDiffuse+DirSpecular(AND)EnvDiffuse+EnvSpecular;

                //Direct
                
                //根据金属度对漫反射在基础颜色与黑色之间进行插值，纯金属的物体不发生漫反射，有点PBR思想
                half3 diffCol=lerp(baseCol,half3(0,0,0),metalness);
                //根据底色对镜面反射在基础颜色与灰色之间进行插值，最后乘上镜面反射强度，其中0.3为经验值
                half3 specCol=lerp(baseCol,half3(0.3,0.3,0.3),tintMask)*specInt;

                //考虑金属与非金属菲涅尔特性的差异，根据金属度对实际菲涅尔在采样菲涅尔与0之间进行插值，因为这里的FresnelRamp为通用纹理，未作出差异化
                half3 fresnel=lerp(fresnelRamp,0.0,metalness);
                half fresnelCol=fresnel.r;
                half fresnelRim=fresnel.g;
                half fresnelSpec=fresnel.b;

                //Diffuse
                half halfLambert=0.5*dot(worldNormal,worldLightDir)+0.5;
                fixed3 diffuseRamp=tex2D(_DiffuseRamp,half2(halfLambert,0.2)).rgb;
                half3 dirDiff=diffCol*diffuseRamp*_LightCol*_LightColor0.rgb;

                //Specular
                half Phong=pow(max(0,dot(worldLightReflectDir,worldNormal)),_SpecPow*specPow);
                //将兰伯特应用到blinn-phong上，漫反射弱的地方，镜面反射也弱；
                half spec=Phong*max(0,dot(worldNormal,worldLightDir));
                spec=max(spec,fresnelSpec);
                spec=spec*_SpecVal;
                half3 dirSpec=specCol*spec*_LightCol*_LightColor0.rgb;

                //Environment

                //Diffuse
                half3 envCol=EnvCol(worldNormal);
                half3 envDiff=envCol*diffCol*_EnvDiffVal;

                //Specular
                //对于一个材质，非金属取菲涅尔高光，金属取金属度，乘以高光强度得到反射度
                half reflectInt=max(fresnelSpec,metalness)*specInt;
                half3 envSpec=specCol*reflectInt*envCube*_EnvSpecVal;
                
                
                //Emission
                half3 emission=emissionInt*diffCol*_EmitCol*_EmitVal;

                //Rim
                half3 rimLight=_RimCol*fresnelRim*rimInt*max(0,worldNormal.g)*_RimVal;

                half3 finalCol=(dirDiff+dirSpec)*shadow+envDiff+envSpec+rimLight+emission;
                finalCol=ApplyColor(finalCol);
                return fixed4(finalCol,1.0);
            }
            ENDCG
        }
    }
    Fallback"Legacy Shaders/Transparent/VertexLit"
}