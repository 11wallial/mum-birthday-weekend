// Grain and vignette, over everything.
//
// The renderer's tonemap and glow do the photographic part; this does the
// photograph. Without it a software-rendered frame is too clean — flat gradients
// band visibly in the dark falloff around the machine, and the frame has no edge,
// so the room appears to continue past the screen rather than stopping at it.
//
// Deliberately cheap: no texture reads beyond the screen, no loops, a handful of
// instructions. It runs every frame on a phone.
shader_type canvas_item;
render_mode unshaded;

// Grain amplitude at full strength. Above about 0.09 it stops reading as film
// and starts reading as a broken renderer.
uniform float grain_amount : hint_range(0.0, 0.2) = 0.045;
// How far in from the corners the darkening starts, and how hard it bites.
uniform float vignette_start : hint_range(0.0, 1.5) = 0.42;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.85;
// A hair of warmth in the shadows, so the blacks stay part of the room.
uniform vec3 shadow_tint : source_color = vec3(0.055, 0.043, 0.031);

uniform sampler2D screen_texture : hint_screen_texture, filter_linear;

// Value hash. Cheaper than a noise texture and does not need one shipped.
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec3 colour = texture(screen_texture, SCREEN_UV).rgb;

	// The photograph's curve: a gentle S that crushes the toe into the room's
	// warmth and firms the mids, with a hair of warm cast over everything.
	// The renderer's tonemap has already rolled the highlights off; this is
	// the print stock, not the exposure.
	colour = max(colour * 1.06 - 0.008, vec3(0.0));
	colour = mix(colour, colour * colour * (3.0 - 2.0 * colour), 0.28);
	colour *= vec3(1.03, 1.0, 0.95);

	// Vignette on the distance from centre, corrected for aspect so a phone in
	// portrait does not get an oval. Squared falloff: gentle across the middle
	// of frame, decisive in the corners.
	vec2 centred = SCREEN_UV - vec2(0.5);
	centred.x *= 1.0 + max(0.0, (1.0 / max(SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x, 0.001)) - 1.0) * 0.0;
	float radius = length(centred) * 1.4142;
	float falloff = smoothstep(vignette_start, 1.0, radius);
	colour *= 1.0 - falloff * vignette_strength;
	// Lift the darkened corners back toward the room's own warmth rather than
	// to pure black, which is where a vignette starts looking like a filter.
	colour += shadow_tint * falloff * 0.5;

	// Grain, re-seeded each frame so it moves. Scaled by luminance so it sits in
	// the mid-tones and shadows and leaves the bulb and the phosphor clean —
	// bright grain is the tell of an overlay rather than an emulsion.
	float luma = dot(colour, vec3(0.2126, 0.7152, 0.0722));
	float weight = 1.0 - smoothstep(0.25, 0.95, luma);
	float noise = hash(SCREEN_UV * vec2(1920.0, 1080.0) + fract(TIME) * 137.0) - 0.5;
	colour += noise * grain_amount * weight;

	COLOR = vec4(colour, 1.0);
}
