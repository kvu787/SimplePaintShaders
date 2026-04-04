shader_type spatial;
render_mode unshaded;
render_mode cull_disabled;

void fragment() {
	ALBEDO = vec3(NORMAL.x);
}
