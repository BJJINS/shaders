#version 300 es
precision mediump float;

uniform vec2 u_resolution;

float inverseLerp(float v, float minValue, float maxValue) {
    return (v - minValue) / (maxValue - minValue);
}

float remap(float x, float y, float a, float b, float value) {
    return mix(a, b, inverseLerp(value, x, y));
}

float opUnion(float a, float b) {
    return min(a, b);
}

float opSubtraction(float a, float b) {
    return max(a, -b);
}

void main() {
    vec3 color = vec3(0.0);

    gl_FragColor = vec4(color, 1.0);
}
