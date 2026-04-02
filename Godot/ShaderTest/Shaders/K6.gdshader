shader_type spatial;
render_mode unshaded;
render_mode cull_disabled;

/*
	This brightness value means that the base color appears at a facing ratio of cosine(37 degrees),
	which means the surface normal forms an angle of 37 degrees with the light direction.

	    cosine(37 degrees) = 0.79863551
	1 - cosine(37 degrees) = 0.20136449
*/
#define BrightnessCosine37Degrees 0.20136449

#define Blue vec4(0.039215688, 0.24705882, 0.78431374, 1)

uniform vec4 BaseColor : source_color = Blue;

/*
	Brightness is defined as the complement of the facing ratio at which the base color appears.

	The facing ratio is a number from 0.0 to 1.0 that indicates how much of the surface aligns with
	the light source. 0.0 means the surface is facing perpendicular or away from the light, so it
	should receive no light. 1.0 means the surface is facing the light directly, so it should
	receive the most light.

	For example, if you want high brightness, you would want the base color to appear at a very
	low facing ratio such as 0.2. This limits darkening to a small range from 0.0 to 0.2 and
	lightening to a much larger range from 0.2 to 1.0. The larger the lightening range is, the
	brighter the object is.
*/
uniform float Brightness : hint_range(0.0, 1.0) = BrightnessCosine37Degrees;

uniform float Shift : hint_range(0.0, 1.0) = 0.0;
uniform float Rotation : hint_range(0.0, 360.0) = 0.0;
uniform float ShadowIntensity : hint_range(0.0, 1.0) = 1.0;
uniform float HighlightIntensity : hint_range(0.0, 1.0) = 1.0;

/*
	This is a rearranged form of Christophe Schlick's bias function.
	It produces an infinitely differentiable curve that intersects (0.5, b).

	NOTE:
	Schlick uses "a" because it's the first letter in the alphabet.
	However, I use "b" because the curve intersects with (0.5, b) and "b" makes more sense as a y-coordinate.

	References:
	1. Graphics Gems IV, 1994, pages 401 to 403, by Christophe Schlick
	2. A Convenient Generalization of Schlick's Bias and Gain Function, 2020, by Jonathan T. Barron
*/
float SchlickA(float a, float t) {
	a = clamp(a, 0.0001, 0.9999);
	t = clamp(t, 0.0, 1.0);

	return ((1.0 - a) * t) / mix(a, 1.0 - a, t);
}

/*
	This is an augmented and vectorized form of Schlick's bias that intersects point (a, b) and is "squished" into the [c, d] range.
*/
vec3 SchlickABCD_Vec3(vec3 a, vec3 b, vec3 c, vec3 d, vec3 t) {
	a = clamp(a, vec3(0.0001), vec3(0.9999));
	b = clamp(b, vec3(0.0001), vec3(0.9999));
	c = clamp(c, vec3(0.0001), vec3(0.9999));
	d = clamp(d, vec3(0.0001), vec3(0.9999));
	t = clamp(t, vec3(0.0), vec3(1.0));

	vec3 k1 = d * (b - c) - a * b * (d - c);
	vec3 k2 = a * c * (d - b);
	vec3 k3 = (b - c) - a * (d - c);
	vec3 k4 = a * (d - b);

	return (k1 * t + k2) / (k3 * t + k4);
}

float MapRange(float aStart, float aEnd, float bStart, float bEnd, float t) {
	return ((bEnd - bStart) / (aEnd - aStart)) * (t - aStart) + bStart;
}

vec2 RotateXY(vec2 xy, float angle) {
	float s = sin(angle);
	float c = cos(angle);
	// Standard CCW Matrix: [ c  -s ]
	//                      [ s   c ]
	// GLSL Column-Major: vec2(c, s), vec2(-s, c)
	mat2 rotation_matrix = mat2(vec2(c, s), vec2(-s, c));
	return rotation_matrix * xy;
}

/*
	This computes the z component of a 3d vector with length=1.
	It assumes that x and y are bounded in [0.0, 1.0].

	We use `sqrt(max(0.0, 1.0 - x*x - y*y))` instead of the simpler `sqrt(1.0 - x*x - y*y)`
	to avoid square rooting a very small negative number caused by float imprecision.

	For example, if x=(2^0.5)/2 and y=(2^0.5)/2, then `1.0 - x*x - y*y` could equal something
	like -0.000000001 due to float imprecision. Then, you would get sqrt(-0.000000001) = NaN.
	Because we know that `1.0 - x*x - y*y` is bounded in [0.0, 1.0], we can use `max` to
	prevent tiny negative numbers.
*/
float ZComponent(float x, float y) {
	return sqrt(max(0.0, 1.0 - x*x - y*y));
}

float XComponent(float y, float z) {
	return sqrt(max(0.0, 1.0 - y*y - z*z));
}

/*
	Typically, the FacingRatio is simply the z component of the surface normal.
	This forms a hemisphere surface with respect to x and y.

	RemapFacingRatio remaps the facing ratio such that the "peak" is shifted along the positive x-axis.
	The output of RemapFacingRatio forms a surface that is smooth (infinitely differentiable) with respect to x and y.
	The remapped surface resembles a warped hemisphere.
*/
float RemapFacingRatio(float shift, float x, float y) {
	float xStart = -XComponent(y, 0.0);
	float xEnd = XComponent(y, 0.0);
	float schlickT = MapRange(xStart, xEnd, 0.0, 1.0, x);
	float schlickA = MapRange(0.0, 1.0, 0.5, 1.0, shift);
	float schlickOut = SchlickA(schlickA, schlickT);
	float remappedX = MapRange(0.0, 1.0, xStart, xEnd, schlickOut);
	float remappedFacingRatio = ZComponent(remappedX, y);

	return remappedFacingRatio;
}

void fragment() {
	// This uses NORMAL, which is the view space normal, effectively making it a matcap shader.
	vec3 normal = normalize(NORMAL);
	vec2 rotatedNormalXY = RotateXY(normal.xy, -1.0 * radians(Rotation));
	float remappedFacingRatio = RemapFacingRatio(Shift, rotatedNormalXY.x, rotatedNormalXY.y);
	float facingRatioPositionOfBaseColor = 1.0 - Brightness;
	vec3 darkPoint = mix(BaseColor.rgb, vec3(0.0, 0.0, 0.0), ShadowIntensity);
	vec3 lightPoint = mix(BaseColor.rgb, vec3(1.0, 1.0, 1.0), HighlightIntensity);

	ALBEDO = SchlickABCD_Vec3(
		vec3(facingRatioPositionOfBaseColor),
		BaseColor.rgb,
		darkPoint,
		lightPoint,
		vec3(remappedFacingRatio));
}

// void ComputeUniforms(float rotation) {
// 	float s = sin(-1.0 * radians(rotation));
// 	float c = cos(-1.0 * radians(rotation));
// 	mat2 rotationMatrix = mat2(vec2(c, s), vec2(-s, c));
// 	float u0 = rotationMatrix[0][0]
// 	float u1 = rotationMatrix[0][1]
// 	float u2 = rotationMatrix[1][0]
// 	float u3 = rotationMatrix[1][1]
// 	float u4 = MapRange(0.0, 1.0, 0.5, 1.0, shift);
// }

// vec3 ComputeAlbedo(float u0, float u1, float u2, float u3, vec3 normal) {
// 	normal = normalize(NORMAL);
// 	vec2 rotatedNormalXY = mat2(u0, u1, u2, u3) * normal.xy;
// 	float x = rotatedNormalXY.x;
// 	float y = rotatedNormalXY.y;
// 	float xEnd = sqrt(max(0.0, 1.0 - y*y));
// 	float xStart = -xEnd;
// 	float schlickT = MapRange(xStart, xEnd, 0.0, 1.0, x);
// 	float schlickOut = (u4 * t) / mix(u5, u4, schlickT);
// 	float remappedX = MapRange(0.0, 1.0, xStart, xEnd, schlickOut);
// 	float remappedFacingRatio = ZComponent(remappedX, y);
// }

float ComputeRemappedFacingRatio(float u0, float u1, float u2, float u3, float u4, float u5, vec3 normal) {
	normal = normalize(normal);
	//vec2 rotatedNormalXY = mat2(u0, u1, u2, u3) * normal.xy;
	vec2 rotatedNormalXY = mat2(vec2(u0, u1), vec2(u2, u3)) * normal.xy;
	float x = rotatedNormalXY.x;
	float y = rotatedNormalXY.y;
	float xEnd = sqrt(max(0.0, 1.0 - y*y));
	float xStart = -xEnd;
	float t = (x - xStart) / (xEnd - xStart);
	float schlickOut = (u4 * t) / mix(u5, u4, t);
	// float remappedX = MapRange(0.0, 1.0, xStart, xEnd, schlickOut);
	// float remappedX = ((bEnd - bStart) / (aEnd - aStart)) * (t - aStart) + bStart;
	// float remappedX = ((bEnd - bStart) / (1.0 - 0.0)) * (schlickOut - 0.0) + bStart;
	// float remappedX = (bEnd - bStart) * schlickOut + bStart;
	// float remappedX = (xEnd - xStart) * schlickOut + xStart;
	float remappedX = (xEnd - xStart) * schlickOut + xStart;
	float remappedFacingRatio = sqrt(max(0.0, 1.0 - remappedX*remappedX - y*y));
	return remappedFacingRatio;
}

// float ZComponent(float x, float y) {
// 	return sqrt(max(0.0, 1.0 - x*x - y*y));
// }

// float SchlickA(float a, float t) {
// 	a = clamp(a, 0.0001, 0.9999);
// 	t = clamp(t, 0.0, 1.0);
// 	return ((1.0 - a) * t) / mix(a, 1.0 - a, t);
// }

// float SchlickA(float a, float t) {
// 	a = clamp(a, 0.0001, 0.9999);
// 	t = clamp(t, 0.0, 1.0);
// 	return (u0 * t) / mix(u1, u0, t);
// }

// float MapRange(float aStart, float aEnd, float bStart, float bEnd, float t) {
// 	return ((bEnd - bStart) / (aEnd - aStart)) * (t - aStart) + bStart;
// }

// /*
// mix = a + (b - a) * t
// */