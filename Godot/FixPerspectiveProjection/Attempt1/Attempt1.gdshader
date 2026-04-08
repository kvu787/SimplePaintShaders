shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

void fragment() {
	// NORMAL is in camera/view space already
	vec3 normal = normalize(NORMAL);
	ALBEDO = vec3(normal.z);
}
