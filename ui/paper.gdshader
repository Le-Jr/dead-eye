shader_type canvas_item;
void fragment() {
	vec2 uv = UV;
	float grain = fract(sin(dot(floor(uv * vec2(1800.,1000.)), vec2(12.9898,78.233))) * 43758.5453);
	float plank = step(.96, fract(uv.y * 9.));
	float veins = sin(uv.x * 250. + sin(uv.y * 100.) * 3.);
	vec3 wood = vec3(.14,.085,.055) + grain * .035 + veins * .012 - plank * .04;
	float vignette = smoothstep(.8,.15,distance(uv,vec2(.5)));
	COLOR = vec4(wood * (.55 + .45*vignette), 1.);
}
