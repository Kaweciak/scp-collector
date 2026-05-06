shader_type spatial;

#include "res://addons/portals/materials/portalclip_mesh.gdshaderinc"
PORTALCLIP_UNIFORMS

uniform sampler2D custom_texture : source_color, filter_linear_mipmap, repeat_enable;

void vertex() {
	// Called for every vertex the material is visible on.
	
	PORTALCLIP_VERTEX
}

void fragment() {
	// Called for every pixel the material is visible on.
	vec4 tex_color = texture(custom_texture, UV);
    ALBEDO = tex_color.rgb;
	
	PORTALCLIP_FRAGMENT
}

//void light() {
//	// Called for every pixel for every light affecting the material.
//	// Uncomment to replace the default light processing function with this one.
//}
