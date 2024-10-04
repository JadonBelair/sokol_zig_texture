@vs vs
layout (location=0) in vec3 aPos;
layout (location=1) in vec2 aTexCoord;
layout (location=2) in vec3 aNormal;

out vec2 TexCoord;
out vec3 FragPos;
out vec3 Normal;

uniform vs_params {
	mat4 model;
	mat4 view;
	mat4 projection;
};

void main() {
	gl_Position = projection * view * model * vec4(aPos, 1.0f);

	TexCoord = aTexCoord;
	FragPos = vec3(model * vec4(aPos, 1.0));
	Normal = mat3(transpose(inverse(model))) * aNormal;
}
@end

@fs fs
out vec4 FragColor;

in vec2 TexCoord;
in vec3 FragPos;
in vec3 Normal;

uniform texture2D _ourTexture;
uniform sampler _ourTexture_smp;
uniform fs_params {
	vec3 light_color;
	vec3 light_pos;
	vec3 view_pos;
};

#define ourTexture sampler2D(_ourTexture, _ourTexture_smp)

void main() {
	float ambient_strength = 0.1f;
	vec3 ambient = ambient_strength * light_color;

	vec3 norm = normalize(Normal);
	vec3 light_dir = normalize(light_pos - FragPos);

	float diff = max(dot(norm, light_dir), 0.0f);
	vec3 diffuse = diff * light_color;

	float specular_strength = 0.5f;

	vec3 view_dir = normalize(view_pos - FragPos);
	vec3 reflect_dir = reflect(-light_dir, norm);

	float spec = pow(max(dot(view_dir, reflect_dir), 0.0f), 32);
	vec3 specular = specular_strength * spec * light_color;
	
	vec3 result = (ambient + diffuse + specular) * texture(ourTexture, TexCoord).rgb;

	FragColor = vec4(result, 1.0f);
}
@end

@fs light_cube_fs
out vec4 FragColor;

in vec2 TexCoord;
in vec3 FragPos;
in vec3 Normal;

void main() {
	FragColor = vec4(1.0f);
}
@end

@program triangle vs fs
@program light_cube vs light_cube_fs
