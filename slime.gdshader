shader_type canvas_item;

void fragment() {
    vec2 grid_size = vec2(22.0, 22.0);
    vec2 uv = floor(UV * grid_size) / grid_size - vec2(0.5);
    
    float dist = length(uv);
    float alpha = step(dist, 0.45) * 0.3;
    COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
