// The charge cable's arc: a pulse of arc-light riding a ribbon from the coil
// to the drivetrain rail when the lever is thrown.
//
// The ribbon's V runs 0..1 along the cable; `charge` is where the pulse head
// is, and anything below -0.5 means idle. The cable geometry never moves — the
// jitter rides only near the head, quantised in time so it flickers the way a
// spark gap does rather than swimming like water.
//
// Additive and unshaded: an arc is its own light. ALBEDO is the final colour
// in unshaded mode (EMISSION is never read there), and black adds nothing, so
// the idle cable costs almost nothing to draw.
shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

uniform float charge = -1.0;
uniform vec3 arc_color : source_color = vec3(0.4, 0.68, 1.0);
uniform float jitter = 0.16;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	float t = floor(TIME * 48.0);
	float near = charge >= -0.5
			? 1.0 - smoothstep(0.0, 0.24, abs(UV.y - charge))
			: 0.0;
	VERTEX += NORMAL * (hash(vec2(UV.y * 41.0, t)) - 0.5) * jitter * near;
	VERTEX.y += (hash(vec2(UV.y * 29.0, t + 7.0)) - 0.5) * jitter * 0.7 * near;
}

void fragment() {
	// A resting ember, so a live cable reads live even between spins.
	float glow = 0.05;
	if (charge >= -0.5) {
		float d = abs(UV.y - charge);
		// The head, and the fading trail it has already burned along.
		glow += exp(-d * d * 240.0) * 2.8;
		glow += exp(-max(charge - UV.y, 0.0) * 8.0) * 0.55
				* (1.0 - step(UV.y, charge) * 0.0) * step(UV.y, charge);
	}
	ALBEDO = arc_color * glow;
	ALPHA = 1.0;
}
