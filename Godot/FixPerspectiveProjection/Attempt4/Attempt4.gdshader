shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// This shader gets the correct facing ratio for both perspective and orthogonal projection cameras
void fragment() {
	vec3 normal = normalize(NORMAL);
	float facingRatio = dot(normal, VIEW);
	ALBEDO = vec3(facingRatio);
}
