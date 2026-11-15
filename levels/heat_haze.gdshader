shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
void fragment() {
	float wave = sin(UV.y*95. + TIME*2.3) * sin(UV.x*31. - TIME);
	vec2 offset = vec2(wave*.0015,0.);
	ALBEDO = texture(screen_texture,SCREEN_UV+offset).rgb;
	ALPHA = .22 * sin(UV.y*3.14159);
}
