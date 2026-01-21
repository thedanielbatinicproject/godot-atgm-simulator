shader_type canvas_item;

// Sound/Echolocation camera effect shader
// Creates an echolocation-style visualization with outlines and waves

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform vec3 base_color : source_color = vec3(0.0, 0.1, 0.15);
uniform vec3 echo_color : source_color = vec3(0.0, 0.7, 1.0);
uniform vec3 highlight_color : source_color = vec3(1.0, 0.5, 0.0);
uniform float edge_threshold : hint_range(0.0, 0.5) = 0.1;
uniform float wave_speed : hint_range(0.5, 3.0) = 1.5;
uniform float wave_frequency : hint_range(1.0, 10.0) = 4.0;

// Sobel edge detection
float get_edge(vec2 uv, vec2 pixel_size) {
	float tl = dot(texture(SCREEN_TEXTURE, uv + vec2(-pixel_size.x, -pixel_size.y)).rgb, vec3(0.299, 0.587, 0.114));
	float t  = dot(texture(SCREEN_TEXTURE, uv + vec2(0.0, -pixel_size.y)).rgb, vec3(0.299, 0.587, 0.114));
	float tr = dot(texture(SCREEN_TEXTURE, uv + vec2(pixel_size.x, -pixel_size.y)).rgb, vec3(0.299, 0.587, 0.114));
	float l  = dot(texture(SCREEN_TEXTURE, uv + vec2(-pixel_size.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float r  = dot(texture(SCREEN_TEXTURE, uv + vec2(pixel_size.x, 0.0)).rgb, vec3(0.299, 0.587, 0.114));
	float bl = dot(texture(SCREEN_TEXTURE, uv + vec2(-pixel_size.x, pixel_size.y)).rgb, vec3(0.299, 0.587, 0.114));
	float b  = dot(texture(SCREEN_TEXTURE, uv + vec2(0.0, pixel_size.y)).rgb, vec3(0.299, 0.587, 0.114));
	float br = dot(texture(SCREEN_TEXTURE, uv + vec2(pixel_size.x, pixel_size.y)).rgb, vec3(0.299, 0.587, 0.114));
	
	float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
	float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
	
	return sqrt(gx*gx + gy*gy);
}

void fragment() {
	vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	vec2 pixel_size = 1.0 / vec2(textureSize(SCREEN_TEXTURE, 0));
	
	// Get luminance of original
	float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Edge detection
	float edge = get_edge(SCREEN_UV, pixel_size * 2.0);
	edge = smoothstep(edge_threshold, edge_threshold + 0.2, edge);
	
	// Create pulsing wave effect from center
	vec2 center_uv = SCREEN_UV - 0.5;
	float dist = length(center_uv);
	float wave = sin(dist * wave_frequency * 10.0 - TIME * wave_speed) * 0.5 + 0.5;
	wave = pow(wave, 4.0) * 0.3;
	
	// Base dark color with subtle depth based on luminance
	vec3 sound_color = base_color + vec3(luminance * 0.1);
	
	// Add edges in echo color
	sound_color = mix(sound_color, echo_color, edge);
	
	// Add wave pulse effect
	sound_color += echo_color * wave * 0.3;
	
	// Highlight bright areas (potential targets/heat sources)
	if (luminance > 0.6) {
		float highlight_strength = (luminance - 0.6) / 0.4;
		sound_color = mix(sound_color, highlight_color, highlight_strength * 0.7);
	}
	
	// Add subtle scan effect
	float scan = sin(SCREEN_UV.y * 400.0 + TIME * 3.0) * 0.02;
	sound_color += vec3(scan);
	
	// Mix with original based on intensity
	vec3 final_color = mix(screen_color.rgb, sound_color, intensity);
	
	COLOR = vec4(final_color, screen_color.a);
}
