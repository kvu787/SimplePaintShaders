shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

void fragment() {
	// NORMAL is in camera/view space already
	vec3 normal = normalize(NORMAL);

	// The direction from the pixel to the camera
	vec3 view_dir = normalize(-VERTEX);
	
	// Dot product returns 1 if parallel, 0 if perpendicular
	float edge_falloff = dot(normal, view_dir);
	ALBEDO = vec3(edge_falloff);
}
