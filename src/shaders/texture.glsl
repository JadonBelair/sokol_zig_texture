@vs vs
layout (location=0) in vec3 aPos;
layout (location=1) in vec2 aTexCoord;

out vec2 TexCoord;

uniform vs_params {
	float aspectRatio;
};

void main() {
	gl_Position = vec4(aPos, 1.0f);
	gl_Position.x *= aspectRatio;

	TexCoord = aTexCoord;
}
@end

@fs fs
out vec4 FragColor;

in vec2 TexCoord;

uniform texture2D _ourTexture;
uniform sampler _ourTexture_smp;

#define ourTexture sampler2D(_ourTexture, _ourTexture_smp)

void main() {
	FragColor = texture(ourTexture, TexCoord);
}
@end

@program triangle vs fs
