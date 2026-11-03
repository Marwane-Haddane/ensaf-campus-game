shader_type canvas_item;
render_mode unshaded;
void fragment() {
	vec2 p=UV;
	vec3 col=mix(vec3(0.008,0.028,0.062),vec3(0.008,0.051,0.109),p.y);
	float curve=0.35+0.58*pow(p.x,0.52);
	float band=exp(-pow((p.y-curve)*14.0,2.0));
	float edge=exp(-pow((p.y-curve-0.012)*95.0,2.0));
	float second=exp(-pow((p.y-(0.12+0.85*pow(p.x,0.42)))*19.0,2.0));
	col+=vec3(0.008,0.070,0.16)*band+vec3(0.01,0.043,0.085)*edge+vec3(0.003,0.025,0.069)*second;
	float vignette=1.0-0.28*length(p-vec2(0.5));
	COLOR=vec4(col*vignette,1.0);
}
