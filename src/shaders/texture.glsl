@vs vs
layout (location=0) in vec3 aPos;
layout (location=1) in vec2 aTexCoord;
layout (location=2) in vec3 aColor;

out vec2 TexCoord;
out vec3 ourColor;

uniform vs_params {
	mat4 model;
	mat4 view;
	mat4 projection;
};

void main() {
	gl_Position = projection * view * model * vec4(aPos, 1.0f);

	TexCoord = aTexCoord;
	ourColor = aColor;
}
@end

@fs fs
out vec4 FragColor;

in vec2 TexCoord;
in vec3 ourColor;

uniform texture2D _ourTexture;
uniform sampler _ourTexture_smp;

#define ourTexture sampler2D(_ourTexture, _ourTexture_smp)

void main() {
	FragColor = texture(ourTexture, TexCoord) * vec4(ourColor, 1.0f);
}
@end

@program triangle vs fs
