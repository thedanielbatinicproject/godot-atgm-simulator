shader_type canvas_item;

// Thermal camera effect shader
// Creates a heat-vision look with warm colors for heat sources

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 1.0;
uniform float heat_threshold : hint_range(0.0, 1.0) = 0.3;
uniform float contrast : hint_range(0.5, 2.0) = 1.2;
uniform vec3 cold_color : source_color = vec3(0.0, 0.0, 0.3);
uniform vec3 cool_color : source_color = vec3(0.0, 0.3, 0.6);
uniform vec3 warm_color : source_color = vec3(1.0, 0.8, 0.0);
uniform vec3 hot_color : source_color = vec3(1.0, 0.2, 0.0);

void fragment() {
	vec4 screen_color = texture(SCREEN_TEXTURE, SCREEN_UV);
	
	// Calculate luminance (perceived brightness)
	float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	
	// Apply contrast
	luminance = (luminance - 0.5) * contrast + 0.5;
	luminance = clamp(luminance, 0.0, 1.0);
	
	// Map luminance to thermal color gradient
	vec3 thermal_color;
	if (luminance < 0.25) {
		thermal_color = mix(cold_color, cool_color, luminance * 4.0);
	} else if (luminance < 0.5) {
		thermal_color = mix(cool_color, warm_color, (luminance - 0.25) * 4.0);
	} else if (luminance < 0.75) {
		thermal_color = mix(warm_color, hot_color, (luminance - 0.5) * 4.0);
	} else {
		thermal_color = mix(hot_color, vec3(1.0, 1.0, 1.0), (luminance - 0.75) * 4.0);
	}
	
	// Add subtle noise/scan lines for realism
	float scanline = sin(SCREEN_UV.y * 800.0) * 0.02;
	thermal_color += vec3(scanline);
	
	// Mix with original based on intensity
	vec3 final_color = mix(screen_color.rgb, thermal_color, intensity);
	
	COLOR = vec4(final_color, screen_color.a);
}
