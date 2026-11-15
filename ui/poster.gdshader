shader_type canvas_item;
void fragment() {
	float grain = fract(sin(dot(floor(UV*vec2(800.,1200.)),vec2(12.9898,78.233)))*43758.5453);
	float edge = min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y));
	vec3 paper = mix(vec3(.73,.60,.39),vec3(.88,.78,.57),smoothstep(0.,.055,edge));
	paper += (grain-.5)*.07;
	float rule = step(UV.y,.018)+step(.982,UV.y);
	COLOR = vec4(paper-rule*.2,1.);
}
