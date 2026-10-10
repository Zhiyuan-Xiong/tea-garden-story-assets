shader_type canvas_item;
uniform sampler2D scene_texture : source_color, filter_linear;
uniform sampler2D distance_mask : filter_linear;
uniform vec4 scene_region = vec4(0.0,0.0,1.0,1.0);
uniform float mist_strength = 0.53;
uniform float near_fade = 0.075;
uniform vec4 mist_color : source_color = vec4(0.970,0.962,0.935,1.0);
uniform int static_count = 0;
uniform vec4 static_zones[4];
uniform int plant_count = 0;
uniform int cloud_count = 0;
uniform vec4 plant_zones[8];
uniform vec2 plant_offsets[8];
uniform vec4 cloud_zones[6];
uniform vec2 cloud_offsets[6];
void fragment() {
	vec2 scene_uv = scene_region.xy + UV*scene_region.zw;
	vec2 motion_offset = vec2(0.0);
	float root_lock = 0.0;
	for (int index=0;index<8;index++) {
		if (index>=plant_count) { break; }
		vec4 zone = plant_zones[index];
		float root_distance = length((scene_uv-zone.xy)*vec2(1920.0,1080.0));
		root_lock = max(root_lock,1.0-smoothstep(5.0,18.0,root_distance));
		vec2 local = vec2((scene_uv.x-zone.x)/zone.z,(zone.y-scene_uv.y)/zone.w);
		float crown = smoothstep(0.0,0.75,local.y)*(1.0-smoothstep(0.85,1.2,local.y));
		float edge = 1.0-smoothstep(0.60,1.0,abs(local.x));
		motion_offset += plant_offsets[index]*crown*edge;
	}
	for (int index=0;index<6;index++) {
		if (index>=cloud_count) { break; }
		vec4 zone = cloud_zones[index];
		vec2 local = (scene_uv-zone.xy)/zone.zw;
		float feather = 1.0-smoothstep(0.25,1.0,dot(local,local));
		motion_offset += cloud_offsets[index]*feather;
	}
	motion_offset *= 1.0-root_lock;
	for (int index=0;index<4;index++) {
		if (index>=static_count) { break; }
		vec4 zone = static_zones[index];
		vec2 outside = max(max(zone.xy-scene_uv,scene_uv-zone.zw),vec2(0.0));
		float keep_motion = smoothstep(0.0,16.0,length(outside*vec2(1920.0,1080.0)));
		motion_offset *= keep_motion;
	}
	vec2 animated_uv = clamp(UV+motion_offset/scene_region.zw,vec2(0.0),vec2(1.0));
	float distance_value = texture(distance_mask,scene_uv).r;
	vec4 source = texture(scene_texture,animated_uv);
	float luminance = dot(source.rgb,vec3(0.2126,0.7152,0.0722));
	source.rgb = mix(vec3(luminance),source.rgb,0.82);
	float fade = clamp(near_fade+mist_strength*distance_value,0.0,0.72);
	source.rgb = mix(source.rgb,mist_color.rgb,fade);
	COLOR = source;
}
