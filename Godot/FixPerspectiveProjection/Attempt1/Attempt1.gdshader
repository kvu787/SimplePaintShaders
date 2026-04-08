shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Works in orthogonal, messes up in perspective
void fragment() {
	// NORMAL is in camera/view space already
	vec3 normal = normalize(NORMAL);
	float facingRatio = normal.z;
	ALBEDO = vec3(facingRatio);
}
