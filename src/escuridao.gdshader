shader_type canvas_item;
// Escuridão com um "buraco" de luz em volta da vela da protagonista.

uniform vec2 centro = vec2(960.0, 540.0);   // posição da vela na tela (px)
uniform vec2 tamanho = vec2(1920.0, 1080.0); // tamanho da tela (px)
uniform float raio = 300.0;                  // raio da luz (px na tela)
uniform float escuro : hint_range(0.0, 1.0) = 0.85;

void fragment() {
	vec2 p = UV * tamanho;
	float d = distance(p, centro);
	float a = smoothstep(raio * 0.3, raio, d) * escuro;
	COLOR = vec4(0.02, 0.015, 0.01, a);
}
