shader_type canvas_item;

uniform sampler2D noise_texture : repeat_enable;
uniform vec4 fog_color : source_color = vec4(0.65, 0.7, 0.8, 0.25);
uniform vec2 speed1 = vec2(8.0, 4.0);
uniform vec2 speed2 = vec2(-6.0, 5.0);

varying vec2 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
		}

void fragment() {
	vec2 uv1 = world_pos * 0.001 + speed1 * 0.001 * TIME;
	vec2 uv2 = world_pos * 0.0007 + speed2 * 0.001 * TIME;
	float noise1 = texture(noise_texture, uv1).r;
	float noise2 = texture(noise_texture, uv2).r;
	float combined_fog = noise1 * noise2 * 1.2;
	float fog_alpha = smoothstep(0.05, 0.55, combined_fog);
	COLOR = vec4(fog_color.rgb, fog_alpha * fog_color.a);
	COLOR = vec4(fog_color.rgb, fog_alpha * fog_color.a * COLOR.a);
	}
	
