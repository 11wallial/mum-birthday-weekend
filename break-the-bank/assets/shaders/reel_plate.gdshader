// One printed cell of a reel strip, baked once at boot by ReelPrint.
//
// The symbol shapes live in SymbolArt as small instruction lists — translate,
// rotate, scale, then one of five distance primitives, each painted in one of
// the symbol's two inks or the press's black, or carved — and this shader is
// the second of the two interpreters of that data (SymbolArt._sample is the
// first). Neither is the original: the instruction list is, which is what
// stops the CPU fallback and the GPU bake drifting apart.
//
// Everything around the symbol — the aged paper, the double keyline, the ink
// wear, the grime at the edges — is composed here per pixel, because
// "printed on a strip" is a property of the whole cell, not of the glyph. The
// old approach drew the glyph alone and floated it over blank enamel, and that
// is exactly why the drums read as toilet rolls.
//
// Nothing here is lit. The art handover found the symbols read as clipart
// pasted on a lit machine, and the reason was that the print carried its own
// light — a painted gloss, a drop shadow, an emboss faked in the albedo. The
// bake now runs three passes: the albedo (flat ink on paper), a normal map
// (the ink standing proud of the paper, the paper's own tooth) and a
// metallic map (the premium symbols' stencil), and the room's key light does
// the rest. A symbol on the drum takes the curvature shading and the shadow
// of the bezel exactly as the brass beside it does.
shader_type canvas_item;
render_mode unshaded;

// Which map this pass is baking: 0 albedo, 1 normal, 2 metallic.
uniform int pass_kind = 0;
// 1.0 for a premium symbol: the ink is metal, stencilled rather than printed.
uniform float metal = 0.0;
// How far the ink stands off the paper, in the symbol's -1..1 space, and how
// steep its shoulder is.
uniform float relief = 0.05;
uniform float shoulder = 0.09;

// 12 floats per op, 3 vec4 rows, up to 14 ops. See SymbolArt.ops_for.
const int MAX_OPS = 14;
uniform int op_count = 0;
uniform vec4 ops[42];

// The symbol's two inks, already darkened to printing strength by the caller.
uniform vec4 ink = vec4(0.5, 0.1, 0.1, 1.0);
uniform vec4 ink2 = vec4(0.2, 0.4, 0.2, 1.0);
// The strip it is printed on, and the ink the press uses for rules, outlines
// and anything the symbol asks to have in black.
uniform vec4 paper = vec4(0.84, 0.81, 0.75, 1.0);
uniform vec4 line_ink = vec4(0.09, 0.075, 0.063, 1.0);

// Pixel size of the cell this instance is baking, so the composition can work
// in physical cell space rather than in rect UV.
uniform vec2 cell_px = vec2(416.0, 256.0);
// The symbol spans -1..1 across this fraction of the cell's short side.
uniform float symbol_scale = 0.9;
// Outline half-width, matching SymbolArt.STROKE.
uniform float stroke = 0.12;
// 0..1: how far gone the print is. Wear belongs to the strip, not the glyph.
uniform float wear = 0.1;
// Decorrelates the paper and wear noise between cells.
uniform float seed = 0.0;


// Cheap value noise: enough for paper grain and ink erosion, and it bakes once.
float hash2(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7)) + seed * 17.31) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash2(i), hash2(i + vec2(1, 0)), u.x),
			mix(hash2(i + vec2(0, 1)), hash2(i + vec2(1, 1)), u.x), u.y);
}

vec2 rot2(vec2 p, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

float sd_circle(vec2 p, float r) {
	return length(p) - r;
}

float sd_box(vec2 p, vec2 half_size, float r) {
	vec2 q = abs(p) - (half_size - vec2(r));
	return length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - r;
}

float sd_rhombus(vec2 p, vec2 half_size) {
	vec2 q = abs(p);
	float gradient = length(vec2(1.0 / half_size.x, 1.0 / half_size.y));
	return (q.x / half_size.x + q.y / half_size.y - 1.0) / gradient;
}

// The interpreter. Returns the signed distance and which ink owns the point:
// additive ops are folded with min and painted in order, later on top, and
// subtractive ops carve the result afterwards — the same fold SymbolArt uses.
vec2 symbol_sample(vec2 p) {
	float added = 1.0e6;
	float carved = -1.0e6;
	float paint = 0.0;
	float nearest = 1.0e6;
	for (int i = 0; i < MAX_OPS; i++) {
		if (i >= op_count) {
			break;
		}
		vec4 o0 = ops[i * 3];
		vec4 o1 = ops[i * 3 + 1];
		vec4 o2 = ops[i * 3 + 2];
		vec2 q = rot2(p, o0.z) - o1.xy;
		int kind = int(o0.x);
		if (kind == 3) {
			// Shear: x narrows as y descends. The bell's flare.
			q.x /= 1.0 + max(q.y + o2.w, 0.0) * o0.w;
		} else if (kind == 4) {
			// Taper: x narrows toward the tip. The star's spokes.
			q.x /= max(1.0 + q.y * o0.w, o2.w);
		}
		q *= o1.zw;
		float d;
		if (kind == 0) {
			d = sd_circle(q, o2.x);
		} else if (kind == 2) {
			d = sd_rhombus(q, o2.xy);
		} else {
			d = sd_box(q, o2.xy, o2.z);
		}
		float mode = o0.y;
		if (mode > 0.5 && mode < 1.5) {
			carved = max(carved, -d);
			continue;
		}
		added = min(added, d);
		if (d <= 0.0 || d < nearest) {
			if (d <= 0.0 || added >= 0.0) {
				paint = mode;
			}
			nearest = min(nearest, d);
		}
	}
	return vec2(max(added, carved), paint);
}

float symbol_distance(vec2 p) {
	return symbol_sample(p).x;
}

float coverage(float d, float pixel) {
	return clamp(0.5 - d / pixel, 0.0, 1.0);
}

void fragment() {
	// Physical cell space, and the -1..1 symbol space inside it.
	vec2 px = UV * cell_px;
	float short_side = min(cell_px.x, cell_px.y);
	float half_span = short_side * 0.5 * symbol_scale;
	vec2 p = (px - cell_px * 0.5) / half_span;
	float pixel = 1.0 / half_span;

	// --- the paper -------------------------------------------------------
	// Grain at two scales, plus faint streaks running the way the strip was
	// rolled (around the drum: cell-local y). Paper is never one value.
	float grain = vnoise(px * 0.11) * 0.6 + vnoise(px * 0.43) * 0.4;
	float streak = vnoise(vec2(px.x * 0.017, px.y * 0.36));
	vec3 col = paper.rgb * (0.84 + 0.1 * grain) * (0.96 + 0.05 * streak);
	// Foxing: sparse warm age spots, stronger toward the cell edges.
	float fox = smoothstep(0.74, 0.96, vnoise(px * 0.05 + 31.7));
	col = mix(col, col * vec3(0.84, 0.74, 0.58), fox * 0.4);

	// --- the plate -------------------------------------------------------
	// A double rule frames every cell: one heavy line, one hairline inside it,
	// which is how value plates on old machines are printed. Distances in px.
	vec2 edge = min(px, cell_px - px);
	float border = min(edge.x, edge.y);

	// The relief and the metal passes leave early with their own answers.
	if (pass_kind == 1) {
		// Height: the ink stands proud of the paper with a soft shoulder, the
		// paper has a fine tooth, and the rules are pressed in. The normal is
		// the height field's slope, sampled by finite difference in the
		// symbol's own space so it scales with the cell.
		float e = 0.012;
		float d0 = 1.0e6;
		float dx = 1.0e6;
		float dy = 1.0e6;
		if (op_count > 0) {
			d0 = symbol_distance(p);
			dx = symbol_distance(p + vec2(e, 0.0));
			dy = symbol_distance(p + vec2(0.0, e));
		}
		float h0 = relief * (1.0 - smoothstep(-shoulder, 0.02, d0));
		float hx = relief * (1.0 - smoothstep(-shoulder, 0.02, dx));
		float hy = relief * (1.0 - smoothstep(-shoulder, 0.02, dy));
		// Paper tooth, and the pressed rules.
		float tooth = 0.0035;
		h0 += vnoise(px * 0.9) * tooth;
		hx += vnoise((px + vec2(1.0, 0.0)) * 0.9) * tooth;
		hy += vnoise((px + vec2(0.0, 1.0)) * 0.9) * tooth;
		h0 -= (1.0 - smoothstep(0.0, 1.5, abs(border - 8.0) - 3.4)) * 0.006;
		vec3 n = normalize(vec3(-(hx - h0) / e, (hy - h0) / e, 1.0));
		COLOR = vec4(n * 0.5 + 0.5, 1.0);
	} else if (pass_kind == 2) {
		float m = 0.0;
		if (op_count > 0 && metal > 0.5) {
			vec2 s = symbol_sample(p);
			// The stencil: the fill is metal, the keyline and the black stay ink.
			m = coverage(s.x, pixel) * (s.y < 2.5 ? 1.0 : 0.0);
		}
		COLOR = vec4(vec3(m), 1.0);
	} else {
	// Grime toward the cell's edges, where the strip has been handled and
	// the bezel's shadow keeps the dust.
	float grime = 1.0 - smoothstep(6.0, 46.0, border);
	col *= 1.0 - grime * 0.22 * (0.6 + 0.4 * vnoise(px * 0.07 + 5.0));
	float rule_a = 1.0 - smoothstep(0.0, 1.5, abs(border - 8.0) - 3.4);
	float rule_b = 1.0 - smoothstep(0.0, 1.2, abs(border - 16.0) - 1.1);
	col = mix(col, line_ink.rgb, rule_a * 0.92 + rule_b * 0.6);
	// The seam between cells: the strip darkens into the joint and a hard gap
	// runs along it, so cells read as segments of a drum, not wallpaper.
	float seam_shade = 1.0 - smoothstep(0.0, 9.0, edge.y);
	col *= 1.0 - seam_shade * 0.34;
	col *= 1.0 - (1.0 - smoothstep(0.0, 1.6, edge.y)) * 0.55;

	// --- the print -------------------------------------------------------
	if (op_count > 0) {
		vec2 sample = symbol_sample(p);
		float d = sample.x;
		vec3 paint = ink.rgb;
		if (sample.y > 1.5 && sample.y < 2.5) {
			paint = ink2.rgb;
		} else if (sample.y > 2.5) {
			paint = line_ink.rgb;
		}
		// Erosion: high-frequency noise eats the coverage near the shape edge,
		// so the ink loses its skin where the strip has been handled.
		float erode = smoothstep(0.25, 0.75, vnoise(px * 0.9 + 7.0));
		float loss = wear * erode * smoothstep(-0.22, 0.02, d);
		float fill = coverage(d, pixel) * (1.0 - loss);
		float outer = coverage(d - stroke, pixel) * (1.0 - loss * 0.7);
		// The keyline, then the fill: flat ink. No shadow, no gloss, no
		// painted emboss — the relief pass and the room's light do those.
		col = mix(col, line_ink.rgb, outer);
		vec3 flat_ink = paint;
		if (metal > 0.5 && sample.y < 2.5) {
			// Metal reads through its albedo: darker and warmer than the ink
			// it replaces, so the metallic map has something to reflect with.
			flat_ink = paint * vec3(0.95, 0.86, 0.62);
		}
		col = mix(col, flat_ink, fill);
	}

	COLOR = vec4(col, 1.0);
	}
}
