shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ground_color : source_color, repeat_enable;
uniform sampler2D ground_normal : hint_normal, repeat_enable;
uniform sampler2D ground_roughness : repeat_enable;
uniform bool textures_ready = false;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = world_position.xz / 2.5;
	float patches = sin(world_position.x * 0.12 + sin(world_position.z * 0.08)) * cos(world_position.z * 0.10);
	vec3 tint = mix(vec3(0.16, 0.25, 0.07), vec3(0.30, 0.36, 0.12), smoothstep(-0.6, 0.6, patches));
	// Sparse-grass photography contains a lot of exposed brown earth. Retain its
	// small-scale detail without multiplying the entire meadow into dark soil.
	vec3 detail = textures_ready ? texture(ground_color, uv).rgb : vec3(0.28);
	ALBEDO = tint * (0.72 + detail * 1.25);
	ROUGHNESS = textures_ready ? texture(ground_roughness, uv).r : 0.95;
	NORMAL_MAP = textures_ready ? texture(ground_normal, uv).rgb : vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.65;
}
