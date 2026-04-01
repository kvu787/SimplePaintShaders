shader_type spatial;
render_mode unshaded;

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

float SchlickA(float a, float t) {
	a = clamp(a, 0.0001, 0.9999);
	t = clamp(t, 0.0, 1.0);

	return ((1.0 - a) * t) / mix(a, 1.0 - a, t);
}

float SchlickABCD(float a, float b, float c, float d, float t) {
	a = clamp(a, 0.0001, 0.9999);
	b = clamp(b, 0.0001, 0.9999);
	c = clamp(c, 0.0001, 0.9999);
	d = clamp(d, 0.0001, 0.9999);
	t = clamp(t, 0.0, 1.0);

	float k1 = d * (b - c) - a * b * (d - c);
	float k2 = a * c * (d - b);
	float k3 = (b - c) - a * (d - c);
	float k4 = a * (d - b);

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
	shift = clamp(shift, 0.0, 1.0);

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
	vec3 normal = normalize(NORMAL);
	vec2 rotatedNormalXY = RotateXY(normal.xy, -1.0 * radians(Rotation));
	float remappedFacingRatio = RemapFacingRatio(Shift, rotatedNormalXY.x, rotatedNormalXY.y);
	float facingRatioPositionOfBaseColor = 1.0 - Brightness;
	vec3 darkPoint = mix(BaseColor.rgb, vec3(0.0, 0.0, 0.0), ShadowIntensity);
	vec3 lightPoint = mix(BaseColor.rgb, vec3(1.0, 1.0, 1.0), HighlightIntensity);

	ALBEDO = vec3(
		SchlickABCD(facingRatioPositionOfBaseColor, BaseColor.r, darkPoint.r, lightPoint.r, remappedFacingRatio),
		SchlickABCD(facingRatioPositionOfBaseColor, BaseColor.g, darkPoint.g, lightPoint.g, remappedFacingRatio),
		SchlickABCD(facingRatioPositionOfBaseColor, BaseColor.b, darkPoint.b, lightPoint.b, remappedFacingRatio));
}
