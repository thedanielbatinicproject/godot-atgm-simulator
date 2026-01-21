shader_type canvas_item;

// Infrared (IR) camera effect shader
// Creates a classic night-vision / IR look with green tint

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float brightness_boost : hint_range(1.0, 3.0) = 1.5;
uniform float contrast : hint_range(0.5, 2.0) = 1.3;
uniform vec3 ir_tint : source_color = vec3(0.2, 1.0, 0.3);
uniform float noise_strength : hint_range(0.0, 0.1) = 0.03;
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.4;

// Simple pseudo-random noise function
float random(vec2 uv) {
	return fract(sin(dot(uv, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Calculate luminance
	float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Boost brightness (IR cameras are more sensitive)
	luminance *= brightness_boost;
	
	// Apply contrast
	luminance = (luminance - 0.5) * contrast + 0.5;
	luminance = clamp(luminance, 0.0, 1.0);
	
	// Apply IR tint
	vec3 ir_color = luminance * ir_tint;
	
	// Add noise for realism (IR cameras have more noise)
	float noise = random(SCREEN_UV + vec2(TIME * 0.1, 0.0)) * noise_strength;
	ir_color += vec3(noise);
	
	// Add scan lines
	float scanline = sin(SCREEN_UV.y * 600.0 + TIME * 2.0) * 0.015;
	ir_color += vec3(scanline);
	
	// Add vignette effect (common in night vision scopes)
	vec2 center_uv = SCREEN_UV - 0.5;
	float vignette = 1.0 - dot(center_uv, center_uv) * vignette_strength * 2.0;
	vignette = clamp(vignette, 0.0, 1.0);
	ir_color *= vignette;
	
	// Add circular scope overlay effect
	float dist_from_center = length(center_uv) * 2.0;
	if (dist_from_center > 0.95) {
		ir_color *= smoothstep(1.0, 0.95, dist_from_center);
	}
	
	// Mix with original based on intensity
	vec3 final_color = mix(screen_color.rgb, ir_color, intensity);
	
	COLOR = vec4(final_color, screen_color.a);
}
