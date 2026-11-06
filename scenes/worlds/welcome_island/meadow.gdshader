shader_type spatial;
render_mode cull_disabled;
uniform sampler2D ground_color : source_color, repeat_enable;
uniform sampler2D ground_normal : hint_normal, repeat_enable;
uniform sampler2D ground_roughness : repeat_enable;
varying vec3 world_position;
void vertex() { world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 uv = world_position.xz / 2.5;
	float patches = sin(world_position.x * 0.12 + sin(world_position.z * 0.08)) * cos(world_position.z * 0.10);
	vec3 tint = mix(vec3(0.66, 0.76, 0.53), vec3(0.96, 0.91, 0.71), smoothstep(-0.6, 0.6, patches));
	ALBEDO = texture(ground_color, uv).rgb * tint;
	ROUGHNESS = texture(ground_roughness, uv).r;
	NORMAL_MAP = texture(ground_normal, uv).rgb;
	NORMAL_MAP_DEPTH = 0.65;
}
