shader_type spatial;
render_mode cull_disabled;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

#define BLUE vec4(0.039215688, 0.24705882, 0.78431374, 1)
uniform vec4 BaseColor : source_color = BLUE;

#define BRIGHTNESS_COSINE_37_DEGREES 0.20136449
uniform float Brightness : hint_range(0.0, 1.0) = BRIGHTNESS_COSINE_37_DEGREES;

uniform float Shift : hint_range(0.0, 1.0) = 0.0;
uniform float Rotation : hint_range(0.0, 360.0) = 0.0;
uniform float DarkPoint : hint_range(0.0, 1.0) = 0.0;
uniform float LightPoint : hint_range(0.0, 1.0) = 1.0;

varying flat float v_rs;
varying flat float v_rc;
varying flat float v_u1;
varying flat float v_u2;
varying flat float v_u3;
varying flat float v_u4;
varying flat vec3 v_k1;
varying flat vec3 v_k2;
varying flat vec3 v_k3;

/*
	The optimized form of this shader should declare these as actual uniforms and the CPU should compute them and pass them in.
*/
struct ShaderUniforms {
	float rs;
	float rc;
	float u1;
	float u2;
	float u3;
	float u4;
	vec3 k1;
	vec3 k2;
	vec3 k3;
};

/*
	This computes all the shader inputs that don't change per pixel.
	The optimized form of this shader should run this on the CPU and then pass the data in ShaderInputs to the GPU.
*/
ShaderUniforms ComputeShaderUniforms(vec4 baseColor, float brightness, float shift, float rotation, float darkPoint, float lightPoint) {
	ShaderUniforms su;

	float rotationRadians = -1.0 * radians(rotation);
	su.rs = sin(rotationRadians);
	su.rc = cos(rotationRadians);
	su.u1 = mix(0.5, 1.0, shift);
	su.u2 = 1.0 - su.u1;
	su.u3 = lightPoint - darkPoint;
	su.u4 = darkPoint;
	float facingRatioPositionOfBaseColor = 1.0 - brightness;
	float a = facingRatioPositionOfBaseColor;
	vec3 b = baseColor.rgb;
	su.k1 = b * (1.0 - a);
	su.k2 = b - a;
	su.k3 = a * (1.0 - b);

	return su;
}

void vertex() {
	ShaderUniforms su = ComputeShaderUniforms(BaseColor, Brightness, Shift, Rotation, DarkPoint, LightPoint);

	v_rs = su.rs;
	v_rc = su.rc;
	v_u1 = su.u1;
	v_u2 = su.u2;
	v_u3 = su.u3;
	v_u4 = su.u4;
	v_k1 = su.k1;
	v_k2 = su.k2;
	v_k3 = su.k3;
}

/*
	The computes the pixel color from the shader inputs and normal.
	The optimized form of this shader should just be this function.
*/
vec3 ComputeAlbedo(float rs, float rc, float u1, float u2, float u3, float u4, vec3 k1, vec3 k2, vec3 k3, vec3 normal) {
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
	float remappedFacingRatioSafe = (abs(y) < 1.0) ? remappedFacingRatio : 0.0;
	float lightDarkAdjustedFacingRatio = u3 * remappedFacingRatioSafe + u4;
	vec3 albedo = (k1 * lightDarkAdjustedFacingRatio) / (k2 * lightDarkAdjustedFacingRatio + k3);

	return albedo;
}

void fragment() {
	ALBEDO = ComputeAlbedo(v_rs, v_rc, v_u1, v_u2, v_u3, v_u4, v_k1, v_k2, v_k3, NORMAL);
}
