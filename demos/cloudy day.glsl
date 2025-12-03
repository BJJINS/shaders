#version 300 es
precision mediump float;

uniform vec2 u_resolution;
uniform float u_time;

out vec4 fragColor;

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

float opIntersection(float a, float b) {
    return max(a, b);
}

float sdfCircle(vec2 p, float r) {
    return length(p) - r;
}

float sdfLine(vec2 p, vec2 a, vec2 b) {
    vec2 ap = p - a;
    vec2 ab = b - a;
    float h = dot(ap, ab) / dot(ab, ab);
    float h_clamped = clamp(h, 0.0, 1.0);
    vec2 closest_point_on_segment = a + h_clamped * ab;
    return length(p - closest_point_on_segment);
}

float sdfBox(vec2 p, vec2 a) {
    vec2 d = abs(p) - a;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// 将二维向量逆时针旋转指定弧度
mat2 rotation2D(float radians) {
    float c = cos(radians);
    float s = sin(radians);
    return mat2(c, -s, s, c);
}

vec3 background(vec2 uv) {
    return mix(
        vec3(0.42, 0.58, 0.75),
        vec3(0.36, 0.46, 0.82),
        smoothstep(0.0, 1.0, pow(uv.y * uv.x, 0.5))
    );
}

float sdfCloud(vec2 p) {
    float puff1 = sdfCircle(p, 100.0);
    float puff2 = sdfCircle(p + vec2(-120, 10), 75.0);
    float puff3 = sdfCircle(p + vec2(120, 10), 75.0);

    return opUnion(opUnion(puff1, puff2), puff3);
}

vec3 renderCloud(vec2 p, vec3 bgColor) {
    float cloud = sdfCloud(p);
    float cloudShadow = sdfCloud(p + vec2(25.0)) - 40.0;
    vec3 cloudColor = mix(bgColor, vec3(0.0), 0.5 * smoothstep(0.0, -100.0, cloudShadow));
    return mix(vec3(1.0), cloudColor, smoothstep(0.0, 1.0, cloud));
}

vec3 renderMovingClouds(vec2 uv, vec3 bg) {
    vec2 p = uv * u_resolution;
    vec3 color = bg;
    for (float i = 0.0; i < 4.0; i += 1.0) {
        vec2 offset = vec2(i * 200.0 + u_time * 100.0, 0.0);
        vec2 pos = p - offset;
        pos = mod(pos, u_resolution);
        pos -= u_resolution * 0.5;
        color = renderCloud(pos, color);
    }
    return color;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    vec2 pixelCoord = (uv - 0.5) * u_resolution;
    vec3 bg = background(uv);
    bg = renderMovingClouds(uv, bg);

    fragColor = vec4(bg, 1.0);
}
