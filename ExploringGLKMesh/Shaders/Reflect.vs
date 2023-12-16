#version 330 core
layout (location = 0) in vec3 position;
layout (location = 1) in vec3 normal;

out vec3 wcNormal;
out vec3 wcPosition;

uniform mat4 projectionMatrix;
uniform mat4 modelMatrix;
uniform mat4 viewMatrix;
uniform mat3 normalMatrix;

void main()
{
    // Transform the position of the vertex
    wcPosition = vec3(modelMatrix * vec4(position, 1.0));
    // ... and normal into world space.
    wcNormal = normalMatrix * normal;
    gl_Position = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
}
