shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float amount = 0.;
void fragment() {
	vec3 rgb = texture(screen_texture, SCREEN_UV).rgb;
	float gray = dot(rgb,vec3(.299,.587,.114));
	float edge = smoothstep(.22,.72,distance(UV,vec2(.5)));
	vec3 tint = mix(vec3(gray)*vec3(1.08,.98,.82),vec3(.24,.035,.018),edge*.62);
	COLOR = vec4(mix(rgb,tint,amount),1.);
}
