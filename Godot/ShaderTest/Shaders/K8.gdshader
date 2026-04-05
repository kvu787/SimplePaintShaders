shader_type spatial;
render_mode cull_disabled;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

#define BLUE vec4(0.039215688, 0.24705882, 0.78431374, 1)
uniform vec4 BaseColor : source_color = BLUE;

#define BRIGHTNESS_COSINE_37_DEGREES 0.20136449
uniform float Brightness : hint_range(0.0, 1.0) = BRIGHTNESS_COSINE_37_DEGREES;

uniform float Shift : hint_range(0.0, 1.0) = 0.0;
uniform float Rotation : hint_range(0.0, 360.0) = 0.0;
uniform float ShadowIntensity : hint_range(0.0, 1.0) = 1.0;
uniform float HighlightIntensity : hint_range(0.0, 1.0) = 1.0;

varying flat float v_rs;
varying flat float v_rc;
varying flat float v_u1;
varying flat float v_u2;
varying flat vec3 v_k1;
varying flat vec3 v_k2;
varying flat vec3 v_k3;
varying flat vec3 v_k4;

/*
	The optimized form of this shader should declare these as actual uniforms and the CPU should compute them and pass them in.
*/
struct ShaderUniforms {
	float rs;
	float rc;
	float u1;
	float u2;
	vec3 k1;
	vec3 k2;
	vec3 k3;
	vec3 k4;
};

/*
	This computes all the shader inputs that don't change per pixel.
	The optimized form of this shader should run this on the CPU and then pass the data in ShaderInputs to the GPU.
*/
ShaderUniforms ComputeShaderUniforms(vec4 baseColor, float brightness, float shift, float rotation, float shadowIntensity, float highlightIntensity) {
	ShaderUniforms su;

	float rotationRadians = -1.0 * radians(rotation);
	su.rs = sin(rotationRadians);
	su.rc = cos(rotationRadians);
	su.u1 = mix(0.5, 1.0, shift);
	su.u2 = 1.0 - su.u1;
	float facingRatioPositionOfBaseColor = 1.0 - brightness;
	vec3 darkRgb = mix(baseColor.rgb, vec3(0.0), shadowIntensity);
	vec3 lightRgb = mix(baseColor.rgb, vec3(1.0), highlightIntensity);
	float a = facingRatioPositionOfBaseColor;
	vec3 b = baseColor.rgb;
	vec3 c = darkRgb;
	vec3 d = lightRgb;
	su.k1 = d * (b - c) - a * b * (d - c);
	su.k2 = a * c * (d - b);
	su.k3 = (b - c) - a * (d - c);
	su.k4 = a * (d - b);

	return su;
}

/*
	The computes the pixel color from the shader inputs and normal.
	The optimized form of this shader should just be this function.
*/
vec3 ComputeAlbedo(float rs, float rc, float u1, float u2, vec3 k1, vec3 k2, vec3 k3, vec3 k4, vec3 normal) {
	normal = normalize(normal);

	float x = normal.x * rc - normal.y * rs;
	float y = normal.x * rs + normal.y * rc;
	float yy = y*y;
	float xStart = -1.0 * sqrt(max(0.0, 1.0 - yy));
	float xEnd = -1.0 * xStart;
	float schlickT = (x - xStart) / (xEnd - xStart);
	float schlickOut = (u2 * schlickT) / mix(u1, u2, schlickT);
	float remappedX = mix(xStart, xEnd, schlickOut);
	float remappedFacingRatio = sqrt(max(0.0, 1.0 - remappedX*remappedX - yy));
	vec3 albedo = (k1 * remappedFacingRatio + k2) / (k3 * remappedFacingRatio + k4);

	return albedo;
}

void vertex() {
	ShaderUniforms su = ComputeShaderUniforms(BaseColor, Brightness, Shift, Rotation, ShadowIntensity, HighlightIntensity);

	v_rs = su.rs;
	v_rc = su.rc;
	v_u1 = su.u1;
	v_u2 = su.u2;
	v_k1 = su.k1;
	v_k2 = su.k2;
	v_k3 = su.k3;
	v_k4 = su.k4;
}

void fragment() {
	ALBEDO = ComputeAlbedo(v_rs, v_rc, v_u1, v_u2, v_k1, v_k2, v_k3, v_k4, NORMAL);
}
