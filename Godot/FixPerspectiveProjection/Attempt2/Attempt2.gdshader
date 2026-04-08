shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Works in perspective, messes up in orthogonal
void fragment() {
	// NORMAL is in camera/view space already
	vec3 normal = normalize(NORMAL);
	// The direction from the pixel to the camera
	vec3 view = normalize(-VERTEX);
	// Dot product returns 1 if parallel, 0 if perpendicular
	float facingRatio = dot(normal, view);
	ALBEDO = vec3(facingRatio);
}
