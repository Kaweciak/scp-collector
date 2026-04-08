shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture;
uniform float distortion_strength : hint_range(0, 1) = 0.0;

void fragment() {
    //Fisheye / Barrel Distortion
    vec2 p = SCREEN_UV - 0.5;
    float r = length(p);;
    
	float k = distortion_strength * 1.2; 
    vec2 fisheye_uv = p * (1.0 + k * r * r * r) + 0.5;
	
    //Wave Distortion
    fisheye_uv.x += sin(fisheye_uv.y * 10.0 + TIME) * 0.02 * distortion_strength;
    fisheye_uv.y += cos(fisheye_uv.x * 10.0 + TIME) * 0.02 * distortion_strength;
    
    //Fetch texture
    vec4 tex = texture(screen_texture, fisheye_uv);
    
    //Vignette
	float vignette_strength = pow(distortion_strength, 0.5);
	float v_start = mix(1.9, 0.2, vignette_strength);
    float v_end = mix(3.0, 0.9, vignette_strength);
    float vignette = 1.0 - smoothstep(v_start, v_end, r);
    
	//Chromatic aberration
	float separation = 0.005 * distortion_strength;
	tex.r = texture(screen_texture, fisheye_uv + vec2(separation, 0.0)).r;
	tex.g = texture(screen_texture, fisheye_uv).g;
	tex.b = texture(screen_texture, fisheye_uv - vec2(separation, 0.0)).b;
	
    //Apply vignette to the color
    COLOR = tex * vignette;
}