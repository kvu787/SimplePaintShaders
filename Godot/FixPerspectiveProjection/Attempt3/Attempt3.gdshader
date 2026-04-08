shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// This shader gets the correct facing ratio for both perspective and orthogonal projection cameras
void fragment() {
	vec3 normal = normalize(NORMAL);
	
	// PROJECTION_MATRIX[3][3] resolves to 0.0 (persp) or 1.0 (ortho)
	// PROJECTION_MATRIX[2][3] resolves to -1.0 (persp) or 0.0 (ortho)
	// This single line mathematically shifts the camera from the origin to infinity.
	vec3 view = normalize(vec3(0.0, 0.0, PROJECTION_MATRIX[3][3]) + VERTEX * PROJECTION_MATRIX[2][3]);
	
	float facingRatio = dot(normal, view);
	
	ALBEDO = vec3(facingRatio);
}
