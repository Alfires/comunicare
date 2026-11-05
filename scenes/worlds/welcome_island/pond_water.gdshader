shader_type spatial;
render_mode cull_disabled;
varying vec3 world_position;
void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float a = sin(world_position.x * 2.3 + world_position.z * 1.1 + TIME * 0.45);
	float b = sin(world_position.z * 3.1 - world_position.x * 0.7 - TIME * 0.3);
	float ripples = a * b;
	ALBEDO = mix(vec3(0.045, 0.16, 0.18), vec3(0.08, 0.24, 0.25), 0.5 + ripples * 0.18);
	ROUGHNESS = 0.24 + ripples * 0.025;
	METALLIC = 0.0;
	NORMAL_MAP = normalize(vec3(a * 0.055, b * 0.055, 1.0)) * 0.5 + 0.5;
}
