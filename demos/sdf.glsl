#version 300 es
precision mediump float;

uniform vec2 u_resolution;
uniform float u_time;

out vec4 fragColor;

vec2 st; // 在全局作用域仅声明，不初始化

vec3 YELLOW = vec3(1.0, 1.0, 0.5);
vec3 BLUE = vec3(0.25, 0.25, 1.0);
vec3 RED = vec3(1.0, 0.25, 0.25);
vec3 GREEN = vec3(0.25, 1.0, 0.25);
vec3 PURPLE = vec3(1.0, 0.25, 1.0);

float inverseLerp(float v, float minValue, float maxValue) {
    return (v - minValue) / (maxValue - minValue);
}

float remap(float x, float y, float a, float b, float value) {
    return mix(a, b, inverseLerp(value, x, y));
}

vec3 backgroundColor() {
    float dis = distance(vec2(0.5), st);
    dis = 1.0 - dis;
    dis = smoothstep(0.0, 0.7, dis);
    dis = remap(0.0, 1.0, 0.3, 1.0, dis);
    return vec3(dis);
}

vec3 drawGrid(vec3 color, vec3 lineColor, float cellSpacing, float lineWidth) {
    vec2 center = st - 0.5;
    vec2 cells = abs(fract(center * u_resolution / cellSpacing) - 0.5);
    float disToEdge = (0.5 - max(cells.x, cells.y)) * cellSpacing;
    float line = smoothstep(0.0, lineWidth, disToEdge);
    return mix(lineColor, color, line);
}

float circle_sdf(vec2 p, float r) {
    return length(p) - r;
}

float line_sdf(vec2 p, vec2 a, vec2 b) {
    vec2 ap = p - a;
    vec2 ab = b - a;
    float t = dot(ap, ab) / dot(ab, ab);
    t = clamp(t, 0.0, 1.0);
    return length(ap - t * ab);
}

float box_sdf(vec2 p, vec2 b) {
    vec2 d = abs(p) - b;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float union_sdf(float a, float b) {
    return min(a, b);
}

float intersection_sdf(float a, float b) {
    return max(a, b);
}

float subtraction_sdf(float a, float b) {
    return max(a, -b);
}

mat2 rotation(float radians) {
    float c = cos(radians);
    float s = sin(radians);
    return mat2(
        c, -s,
        s, c
    );
}

void main() {
    st = gl_FragCoord.xy / u_resolution;
    vec2 pixelCoord = (st - 0.5) * u_resolution;
    vec3 color = backgroundColor();
    color = drawGrid(color, vec3(0.5), 10.0, 1.0);
    color = drawGrid(color, vec3(0.0), 100.0, 2.0);

    vec2 pos = pixelCoord - vec2(0.0, 400.0);
    float d_circle_1 = circle_sdf(pos, 200.0);
    pos = pixelCoord + vec2(400.0);
    float d_circle_2 = circle_sdf(pos, 200.0);
    pos = pixelCoord + vec2(-400.0, 400.0);
    float d_circle_3 = circle_sdf(pos, 200.0);

    float d = union_sdf(d_circle_1, d_circle_2);
    d = union_sdf(d, d_circle_3);

    pos = rotation(u_time) * pixelCoord;
    float d_box = box_sdf(pos, vec2(300.0));
    d = subtraction_sdf(d, d_box);
    color = mix(RED, color, step(0.0, d));

    fragColor = vec4(color, 1.0);
}
