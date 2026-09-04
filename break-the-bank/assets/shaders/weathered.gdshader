// A scanned surface that knows which way it is facing.
//
// StandardMaterial3D can tile a scan and it can tint it, but it cannot ask where
// a face points — and that question is most of what makes a surface look like it
// has been somewhere. Dust settles on things that face up. Grime runs down
// things that face out. Neither is random, and a noise map cannot fake either,
// because it does not know which way is up.
//
// Everything is projected from world space, so none of the primitives the
// machine is built from need UVs, and a 0.2m bolt and a 14m floor show grain of
// the same physical size.
shader_type spatial;
render_mode blend_mix, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_map : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_map : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
// Ambient occlusion (R), roughness (G), metallic (B), packed into one image.
uniform sampler2D arm_map : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;

uniform vec4 tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float tiles_per_metre : hint_range(0.1, 20.0) = 1.0;
uniform float normal_depth : hint_range(0.0, 3.0) = 1.0;
uniform float metallic_amount : hint_range(0.0, 1.0) = 0.0;
uniform bool metallic_from_map = false;

// Dust. Settles on upward faces, and on nothing else.
uniform vec4 dust_colour : source_color = vec4(0.33, 0.31, 0.27, 1.0);
uniform float dust_amount : hint_range(0.0, 1.0) = 0.55;
// How far off level a face can be before dust stops sticking to it. Cosine of
// the angle: 0.35 is roughly 70 degrees, so gently sloped faces still collect.
uniform float dust_grip : hint_range(0.0, 1.0) = 0.35;

// Grime. Runs down vertical faces, so it is strongest where dust is weakest.
uniform float grime_amount : hint_range(0.0, 1.0) = 0.4;
// How much finer the second normal sample is than the first. Micro-grain at
// arm's length without shipping a second, larger map for it.
uniform float detail_scale : hint_range(1.0, 24.0) = 9.0;
uniform float detail_depth : hint_range(0.0, 1.0) = 0.35;

varying vec3 world_position;
varying vec3 world_normal;

void vertex() {
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Blend weights for projecting along the three world axes. Raised to a power so
// the seams between projections are narrow rather than a smeared third of the
// surface.
vec3 triplanar_weights(vec3 n) {
	vec3 w = pow(abs(n), vec3(4.0));
	return w / max(w.x + w.y + w.z, 0.0001);
}

vec4 triplanar(sampler2D tex, vec3 p, vec3 w) {
	return texture(tex, p.zy) * w.x
		+ texture(tex, p.xz) * w.y
		+ texture(tex, p.xy) * w.z;
}

void fragment() {
	vec3 n = normalize(world_normal);
	vec3 weights = triplanar_weights(n);
	vec3 uvw = world_position * tiles_per_metre;

	vec3 base = triplanar(albedo_map, uvw, weights).rgb;
	vec3 arm = triplanar(arm_map, uvw, weights).rgb;

	// Two samples of the same normal map at different scales: the coarse one is
	// the surface, the fine one is its grain. Averaging the tangent-space
	// vectors is crude next to a proper reoriented blend, but at these depths
	// the difference is not visible and this costs one lerp.
	vec3 coarse = triplanar(normal_map, uvw, weights).rgb;
	vec3 fine = triplanar(normal_map, uvw * detail_scale, weights).rgb;
	vec3 packed_normal = mix(coarse, fine, detail_depth);

	// How level this face is. 1 facing straight up, 0 facing down or sideways.
	float upness = smoothstep(dust_grip, 1.0, n.y);
	// Dust is not uniform: it drifts. The arm map's occlusion channel already
	// describes where a surface is recessed, which is exactly where dust
	// collects, so it doubles as the drift pattern for free.
	float dust = upness * dust_amount * mix(0.55, 1.0, arm.r);

	// Grime runs down what dust cannot sit on. Strongest on true verticals,
	// biased downward so it accumulates at the bottom of a face.
	float vertical = 1.0 - abs(n.y);
	float run = fract(world_position.y * tiles_per_metre * 0.5);
	float grime = vertical * grime_amount * mix(0.35, 1.0, 1.0 - run) * (1.0 - arm.r * 0.5);

	vec3 colour = base * tint.rgb;
	colour = mix(colour, dust_colour.rgb, dust);
	colour *= 1.0 - grime * 0.45;

	ALBEDO = colour;
	// Dust is matte and grime is not: both raise roughness, and dust raises it
	// hardest. A dusty surface that still reflects is the tell of a decal.
	ROUGHNESS = clamp(arm.g + dust * 0.45 + grime * 0.15, 0.04, 1.0);
	METALLIC = metallic_from_map ? arm.b * metallic_amount : metallic_amount;
	// Dust sits on top of the metal and hides it.
	METALLIC *= 1.0 - dust;
	AO = arm.r;
	AO_LIGHT_AFFECT = 0.35;
	NORMAL_MAP = packed_normal;
	NORMAL_MAP_DEPTH = normal_depth * (1.0 - dust * 0.6);
}
