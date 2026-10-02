shader_type canvas_item;
// Torna transparente o fundo cor de papel de uma imagem (para recortar
// objetos gerados sobre fundo liso, como altares e criaturas).

uniform float limiar : hint_range(0.0, 1.0) = 0.82;   // quão claro o papel é
uniform float suavidade : hint_range(0.0, 0.3) = 0.08;

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float lum = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float sat = max(c.r, max(c.g, c.b)) - min(c.r, min(c.g, c.b));
	float papel = smoothstep(limiar - suavidade, limiar, lum) * (1.0 - smoothstep(0.08, 0.2, sat));
	COLOR = vec4(c.rgb, c.a * (1.0 - papel));
}
