shader_type spatial;
render_mode unshaded, specular_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

/*
	From the official Godot docs (https://docs.godotengine.org/en/4.6/tutorials/shaders/shader_reference/spatial_shader.html#fragment-built-ins):
	NORMAL = Normal that comes from the vertex() function, in view space.
	VIEW = Normalized vector from fragment position to camera (in view space). This is the same for both perspective and orthogonal cameras.
*/

/*
	Why do we need this function instead of simply using NORMAL.xy?

	Using NORMAL.xy assumes the camera shoots perfectly straight, parallel rays out of the screen,
	which is true for an orthogonal camera. You can just use NORMAL.xy to get correct results for
	an orthogonal camera.

	But for a perspective camera, the rays fan outward like a cone. If we just use NORMAL.xy for a
	perspective camera, the shading for objects at the edges of the screen will look shifted and
	incorrect because the math would ignore the angle of the fanned-out ray hitting them. This
	function manually corrects the normal based on the exact angle of the specific ray hitting that
	exact pixel.
*/
vec2 ComputePerspectiveCorrectedNormal(vec3 normal, vec3 view) {
	normal = normalize(normal);
	view = normalize(view);

	// 1. Ternary Singularity Fix
	// If the view vector is almost perfectly parallel to the Y-axis, then swap the reference UP
	// vector to the X-axis to prevent a zero-vector cross product.
	vec3 upVector = abs(view.y) > 0.999 ? vec3(1.0, 0.0, 0.0) : vec3(0.0, 1.0, 0.0);

	// 2. Construct an orthogonal basis using the VIEW vector as the localized Z-axis.
	vec3 xAxis = normalize(cross(upVector, view));
	vec3 yAxis = cross(view, xAxis);

	// 3. Project the normal onto our new X and Y axes.
	// Note: If you also did dot(normal, view), you would get your facing ratio back.
	vec2 corrected_xy = vec2(dot(normal, xAxis), dot(normal, yAxis));

	return corrected_xy;
}

void fragment() {
	vec2 corrected_xy = ComputePerspectiveCorrectedNormal(NORMAL, VIEW);

	// 4. Map from [-1.0, 1.0] to [0.0, 1.0] so it renders properly as visible colors.
	corrected_xy = corrected_xy * 0.5 + 0.5;

	// X will show as Red, Y will show as Green
	ALBEDO = vec3(corrected_xy.x, corrected_xy.y, 0.0);
}
