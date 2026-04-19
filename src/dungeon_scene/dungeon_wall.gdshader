shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, unshaded;

// Torch and distance attenuation are simulated inside the shader instead
// of relying on Godot's clustered light path, which was not contributing
// reliably for the ImmediateMesh + SubViewport combination this scene
// uses. The OmniLight3D and WorldEnvironment remain in the scene for
// fog / ambient coherence.

uniform vec4 torch_color : source_color = vec4(1.0, 0.88, 0.65, 1.0);
uniform float torch_range = 8.0;
uniform float torch_energy : hint_range(0.0, 4.0) = 1.8;
uniform float torch_focus : hint_range(0.5, 3.0) = 1.2;

uniform float ambient_floor : hint_range(0.0, 1.0) = 0.55;

uniform float noise_strength : hint_range(0.0, 1.0) = 0.25;
uniform float noise_scale = 6.0;

uniform float brick_strength : hint_range(0.0, 1.0) = 0.35;
uniform float brick_height = 0.5;
uniform float brick_width = 1.0;
uniform float brick_line_thickness : hint_range(0.01, 0.2) = 0.05;

uniform float door_plank_width = 0.35;
uniform float door_plank_line_thickness : hint_range(0.01, 0.15) = 0.05;
uniform float door_plank_strength : hint_range(0.0, 1.0) = 0.5;
uniform float door_band_thickness : hint_range(0.02, 0.2) = 0.08;
uniform float door_band_strength : hint_range(0.0, 1.0) = 0.45;

uniform float face_shade_min : hint_range(0.3, 1.0) = 0.65;

uniform float distance_ao_near = 3.0;
uniform float distance_ao_far = 12.0;
uniform float distance_ao_min : hint_range(0.0, 1.0) = 0.55;

varying vec3 v_world_pos;
varying vec3 v_world_normal;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
	return fract(p.x * p.y);
}

float value_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 an = abs(v_world_normal);
	vec2 coord;
	bool is_vertical_wall = false;
	if (an.y > an.x && an.y > an.z) {
		coord = v_world_pos.xz;
	} else if (an.x > an.z) {
		coord = vec2(v_world_pos.z, v_world_pos.y);
		is_vertical_wall = true;
	} else {
		coord = vec2(v_world_pos.x, v_world_pos.y);
		is_vertical_wall = true;
	}

	// CellMeshBuilder encodes surface kind in COLOR.a: < 0.75 means the
	// wood / plank path, otherwise stone. Keeps the shader decoupled from
	// the specific RGB palette.
	bool is_door = COLOR.a < 0.75;

	float speckle;
	if (is_door) {
		float grain = value_noise(vec2(coord.x * 2.5, coord.y * 18.0));
		speckle = mix(0.86, 1.06, grain);
	} else {
		float n = value_noise(coord * noise_scale);
		speckle = mix(1.0 - noise_strength * 0.5, 1.0 + noise_strength * 0.15, n);
	}

	float pattern = 1.0;
	if (is_vertical_wall) {
		if (is_door) {
			float plank_x = mod(coord.x, door_plank_width) / door_plank_width;
			float plank_line = smoothstep(0.0, door_plank_line_thickness, plank_x)
			                 * (1.0 - smoothstep(1.0 - door_plank_line_thickness, 1.0, plank_x));
			float plank_factor = mix(1.0 - door_plank_strength, 1.0, plank_line);
			float door_y = clamp(coord.y, 0.0, 2.0) / 2.0;
			float band_mask = 0.0;
			band_mask = max(band_mask, 1.0 - smoothstep(door_band_thickness, door_band_thickness * 1.6, abs(door_y - 0.28)));
			band_mask = max(band_mask, 1.0 - smoothstep(door_band_thickness, door_band_thickness * 1.6, abs(door_y - 0.72)));
			float band_factor = mix(1.0, 1.0 - door_band_strength, band_mask);
			pattern = plank_factor * band_factor;
		} else {
			float row_idx = floor(coord.y / brick_height);
			float row_y = mod(coord.y, brick_height) / brick_height;
			float x_offset = mod(row_idx, 2.0) * brick_width * 0.5;
			float row_x = mod(coord.x + x_offset, brick_width) / brick_width;
			float h_line = smoothstep(0.0, brick_line_thickness, row_y)
			             * (1.0 - smoothstep(1.0 - brick_line_thickness, 1.0, row_y));
			float v_line = smoothstep(0.0, brick_line_thickness, row_x)
			             * (1.0 - smoothstep(1.0 - brick_line_thickness, 1.0, row_x));
			float line_mask = min(h_line, v_line);
			pattern = mix(1.0 - brick_strength, 1.0, line_mask);
		}
	}

	vec3 to_cam_vec = CAMERA_POSITION_WORLD - v_world_pos;
	float dist = length(to_cam_vec);
	vec3 to_cam = to_cam_vec / max(dist, 0.0001);

	float torch_falloff = 1.0 - smoothstep(0.0, torch_range, dist);
	torch_falloff = pow(torch_falloff, torch_focus);
	vec3 torch_light = torch_color.rgb * (torch_falloff * torch_energy);

	float ndotl = max(dot(v_world_normal, to_cam), 0.0);
	float face_shade = mix(face_shade_min, 1.0, ndotl);

	float dao = mix(1.0, distance_ao_min,
	                smoothstep(distance_ao_near, distance_ao_far, dist));

	vec3 base = COLOR.rgb * speckle * pattern;
	vec3 illumination = vec3(ambient_floor) + torch_light;

	ALBEDO = base * illumination * face_shade * dao;
}
