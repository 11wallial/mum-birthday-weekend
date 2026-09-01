// The face of the debt terminal: a domed glass tube in front of a phosphor
// raster, fed by a SubViewport rendering the ledger as plain text.
//
// The content stays honest — it is a Label the room writes to, rendered at
// terminal resolution — and everything CRT about the picture happens here:
// the dome, the barrel distortion, the scanlines, the slow rolling band, the
// mains flicker, and the fixed streak of the room's key light on the glass.
// Unshaded, because a monitor is its own light source; what it gives the room
// is handled by the green spill light beside it.
shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D screen_tex : source_color, filter_nearest;
uniform vec3 phosphor : source_color = vec3(0.353, 1.0, 0.427);
// How far the glass bows toward the viewer at the centre, in metres.
uniform float bulge = 0.045;
// How much the picture bows with it.
uniform float curve = 0.1;
uniform float scan_count = 96.0;
uniform float brightness = 1.6;

void vertex() {
	vec2 c = UV * 2.0 - 1.0;
	VERTEX.z += bulge * (1.0 - 0.5 * dot(c, c));
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r2 = dot(c, c);
	// Barrel: the sample point spreads outward toward the edges, so straight
	// rows of text bow the way the glass does.
	vec2 uv = (c * (1.0 + curve * r2)) * 0.5 + 0.5;
	vec3 col = vec3(0.0);
	if (uv.x > 0.0 && uv.x < 1.0 && uv.y > 0.0 && uv.y < 1.0) {
		vec3 t = texture(screen_tex, uv).rgb;
		float lum = max(t.r, max(t.g, t.b));
		// Scanlines, a band rolling slowly down the frame, and two mains
		// flickers just out of phase — the three tells of a live tube.
		float scan = 0.78 + 0.22 * sin(uv.y * scan_count * 6.2832);
		float roll = 0.93 + 0.07
				* smoothstep(0.35, 0.0, abs(fract(uv.y * 0.7 - TIME * 0.041) - 0.5));
		float flick = 0.95 + 0.03 * sin(TIME * 71.0) + 0.02 * sin(TIME * 11.3);
		col = phosphor * lum * (scan * 0.65 + 0.35) * roll * flick * brightness;
		// The tube's own resting glow: a dark screen is grey-green, not black.
		col += phosphor * 0.05 * (1.0 - r2 * 0.6) * flick;
	}
	// The picture fades into the bezel rather than ending at a hard row.
	col *= smoothstep(1.0, 0.8, r2);
	// One fixed diagonal streak: the key light, reflected in curved glass.
	float streak = exp(-pow((c.x + c.y * 0.55 - 0.3) * 3.0, 2.0)) * 0.045;
	// Unshaded means ALBEDO is the final colour — EMISSION never reaches the
	// screen in this mode, which is exactly the mistake that shipped a black
	// monitor the first time this shader ran.
	ALBEDO = col + vec3(streak * 1.2, streak, streak * 0.8);
}
