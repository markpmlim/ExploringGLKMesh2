#version 330 core

// Incoming per vertex... position and texture coordinates
layout (location = 0) in vec3 position;

uniform mat4   projectionMatrix;
uniform mat4   modelMatrix;
uniform mat4   viewMatrix;

// Output to the fragment shader
smooth out vec3 texCoords;

void main(void)
{
	// Pass position as the 3D texture coordinates
	texCoords = position;

	// Don't forget to transform the geometry!
    vec4 pos = projectionMatrix * viewMatrix * modelMatrix * vec4(position, 1.0);
    // The OpenGL function glDepthFunc(GL_LEQUAL) must be called for
    // the instruction below to work.
    gl_Position = pos.xyww;
}
