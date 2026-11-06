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
	vec3 tint = mix(vec3(0.66, 0.76, 0.53), vec3(0.96, 0.91, 0.71), smoothstep(-0.6, 0.6, patches));
	ALBEDO = textures_ready ? texture(ground_color, uv).rgb * tint : vec3(0.29, 0.37, 0.19) * tint;
	ROUGHNESS = textures_ready ? texture(ground_roughness, uv).r : 0.95;
	NORMAL_MAP = textures_ready ? texture(ground_normal, uv).rgb : vec3(0.5, 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.65;
}
