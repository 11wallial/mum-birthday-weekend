// A receipt, as paper: grain, a perforated top, a torn bottom, a curl at the
// foot, and the room's warmth on it. Drawn behind the printed lines by
// PayoutReceipt; the type sits on top unshaded so it stays crisp.
//
// The receipt was a white rectangle floating over the world — the art
// handover's "engine default" finding. It cannot be lit by the scene from a
// canvas layer, so this does the next honest thing: it takes the key light's
// tint and falls off toward the foot the way paper hanging off a printer does.
shader_type canvas_item;

uniform vec4 paper : source_color = vec4(0.9, 0.87, 0.8, 1.0);
uniform vec4 key_tint : source_color = vec4(1.0, 0.9, 0.75, 1.0);
// Pixels of torn fringe at the foot, in the rect's own pixels.
uniform float tear_px = 14.0;
uniform float perforation_px = 6.0;
uniform vec2 size_px = vec2(320.0, 400.0);
uniform float seed = 3.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 13.7) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x),
			mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}

void fragment() {
	vec2 px = UV * size_px;
	// Grain, and the faint streaks a thermal roll carries along its length.
	float grain = vnoise(px * 0.5) * 0.5 + vnoise(px * 2.1) * 0.5;
	float streak = vnoise(vec2(px.x * 0.02, px.y * 0.4));
	vec3 col = paper.rgb * (0.98 + 0.08 * grain) * (0.97 + 0.04 * streak);
	// The key light from above: bright at the head, falling to the curl.
	float fall = mix(1.0, 0.82, smoothstep(0.6, 1.0, UV.y));
	col *= key_tint.rgb * fall;
	// The curl at the foot: a band of shadow then a hairline of light where
	// the paper turns back toward the lamp.
	float curl = smoothstep(0.92, 0.985, UV.y);
	col *= 1.0 - curl * 0.22;
	col += vec3(0.08) * smoothstep(0.985, 1.0, UV.y) * (1.0 - curl * 0.5);
	// The torn foot: alpha cut by noise over the last tear_px.
	float foot = size_px.y - px.y;
	float tear = vnoise(vec2(px.x * 0.12, 3.0)) * tear_px + vnoise(vec2(px.x * 0.7, 9.0)) * 3.0;
	float alpha = step(tear, foot + tear_px * 0.5);
	// The perforation along the head: a row of holes.
	float head = px.y;
	if (head < perforation_px) {
		float hole = step(0.5, fract(px.x / 9.0)) * step(head, perforation_px * 0.6);
		alpha *= 1.0 - hole;
	}
	COLOR = vec4(col, alpha * paper.a);
}
