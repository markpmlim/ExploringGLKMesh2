#version 330 core
out vec4 FragColor;

in vec3 wcNormal;               // in world space
in vec3 wcPosition;

uniform samplerCube cubeMap;

uniform vec3 cameraPosition;    // in world space

void main()
{
    // Compute vector from the camera/eye to the surface.
    vec3 incidentRay = normalize(wcPosition - cameraPosition);
    vec3 reflectedRay = reflect(incidentRay, normalize(wcNormal));
    FragColor = texture(cubeMap, reflectedRay);
}
