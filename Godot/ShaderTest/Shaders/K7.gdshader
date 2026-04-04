shader_type spatial;
render_mode unshaded;
render_mode cull_disabled;

#define BLUE vec4(0.039215688, 0.24705882, 0.78431374, 1)
uniform vec4 BaseColor : source_color = BLUE;

#define BRIGHTNESS_COSINE_37_DEGREES 0.20136449
uniform float Brightness : hint_range(0.0, 1.0) = BRIGHTNESS_COSINE_37_DEGREES;

uniform float Shift : hint_range(0.0, 1.0) = 0.0;
uniform float Rotation : hint_range(0.0, 360.0) = 0.0;
uniform float ShadowIntensity : hint_range(0.0, 1.0) = 1.0;
uniform float HighlightIntensity : hint_range(0.0, 1.0) = 1.0;

struct ShaderInputs {
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
ShaderInputs ComputeShaderInputs(vec4 baseColor, float brightness, float shift, float rotation, float shadowIntensity, float highlightIntensity) {
	ShaderInputs si;

	float rotationRadians = -1.0 * radians(rotation);
	si.rs = sin(rotationRadians);
	si.rc = cos(rotationRadians);
	si.u1 = mix(0.5, 1.0, shift);
	si.u2 = 1.0 - si.u1;
	float facingRatioPositionOfBaseColor = 1.0 - brightness;
	vec3 darkRgb = mix(baseColor.rgb, vec3(0.0), shadowIntensity);
	vec3 lightRgb = mix(baseColor.rgb, vec3(1.0), highlightIntensity);
	float a = facingRatioPositionOfBaseColor;
	vec3 b = baseColor.rgb;
	vec3 c = darkRgb;
	vec3 d = lightRgb;
	si.k1 = d * (b - c) - a * b * (d - c);
	si.k2 = a * c * (d - b);
	si.k3 = (b - c) - a * (d - c);
	si.k4 = a * (d - b);

	return si;
}

/*
	The computes the pixel color from the shader inputs and normal.
	The optimized form of this shader should just be this function.
*/
vec3 ComputeAlbedo2(ShaderInputs si, vec3 normal) {
	normal = normalize(normal);

	float x = normal.x * si.rc - normal.y * si.rs;
	float y = normal.x * si.rs + normal.y * si.rc;
	float xStart = -1.0 * sqrt(max(0.0, 1.0 - y*y));
	float xEnd = -1.0 * xStart;
	float schlickT = (x - xStart) / (xEnd - xStart);
	float schlickOut = (si.u2 * schlickT) / mix(si.u1, si.u2, schlickT);
	float remappedX = mix(xStart, xEnd, schlickOut);
	float remappedFacingRatio = sqrt(max(0.0, 1.0 - remappedX*remappedX - y*y));
	vec3 albedo = (si.k1 * remappedFacingRatio + si.k2) / (si.k3 * remappedFacingRatio + si.k4);

	return albedo;
}

void fragment() {
	ShaderInputs shaderInputs = ComputeShaderInputs(BaseColor, Brightness, Shift, Rotation, ShadowIntensity, HighlightIntensity);
	ALBEDO = ComputeAlbedo2(shaderInputs, NORMAL);
}
