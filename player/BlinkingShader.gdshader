shader_type canvas_item;

//How closed the eyes are
uniform float blink_progress : hint_range(0.0, 1.0) = 0.0;
//Softness of the eyelid edge
uniform float smoothness : hint_range(0.0, 0.5) = 0.1;
//Strength of the oval curve
uniform float curvature : hint_range(0.0, 2.0) = 0.1;

void fragment() {
    vec2 uv = SCREEN_UV;
	
	//Calculate the horizonatal distance from the center
	float x_dist = abs(uv.x - 0.5) * 2.0;
	
	//Create a parabolic curve for the eyelids
	float curve_offset = pow(x_dist, 2.0) * curvature;
	
	//Adjust the blink progress based on the curvature
	float adjusted_progress = clamp(blink_progress + curve_offset, 0.0, 1.0);
	float half_progress = (adjusted_progress * (0.5 + smoothness));
    
    //Calculate the position of the top and bottom eyelids
    float top_eyelid = smoothstep(half_progress, half_progress - smoothness, uv.y);
    float bottom_eyelid = smoothstep(1.0 - half_progress, 1.0 - half_progress + smoothness, uv.y);
    
    //Combine eyelids and set the color to black
    float mask = clamp(top_eyelid + bottom_eyelid, 0.0, 1.0);
    COLOR = vec4(0.0, 0.0, 0.0, mask);
}