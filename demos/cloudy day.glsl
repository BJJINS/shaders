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

float window(float center, float width, float x) {
    return 1.0 - smoothstep(center - width, center + width, x);
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

float random(vec2 a) {
    float t = dot(a, vec2(36.5323, 73.945));
    return sin(t);
}

vec3 renderSun(vec2 p, vec3 bgColor) {
    vec2 center = vec2(200.0, u_resolution.y * 0.8);
    float radius = 100.0;
    float t = smoothstep(0.0, -15.0, sdfCircle(p - center, radius));
    return mix(bgColor, vec3(0.84, 0.62, 0.26), t);
}

vec3 background(vec2 uv) {
    float t = smoothstep(0.0, 1.0, pow(uv.y * uv.x, 0.5));

    vec3 morning = mix(
            vec3(0.44, 0.64, 0.84),
            vec3(0.34, 0.51, 0.94),
            t
        );
    vec3 midday = mix(
            vec3(0.42, 0.58, 0.75),
            vec3(0.36, 0.46, 0.82),
            t
        );
    vec3 evening = mix(
            vec3(0.82, 0.51, 0.25),
            vec3(0.88, 0.71, 0.39),
            t
        );
    vec3 night = mix(
            vec3(0.07, 0.1, 0.19),
            vec3(0.19, 0.2, 0.29),
            t
        );

    float dayLength = 20.0;
    float dayTime = mod(u_time, dayLength);
    vec3 color;

    if (dayTime < dayLength * 0.25) {
        color = mix(morning, midday, smoothstep(0.0, dayLength * 0.25, dayTime));
    } else if (dayTime < dayLength * 0.5) {
        color = mix(midday, evening, smoothstep(dayLength * 0.25, dayLength * 0.5, dayTime));
    } else if (dayTime < dayLength * 0.75) {
        color = mix(evening, night, smoothstep(dayLength * 0.5, dayLength * 0.75, dayTime));
    } else {
        color = mix(night, morning, smoothstep(dayLength * 0.75, dayLength, dayTime));
    }

    vec2 pixelCoord = uv * u_resolution;
    float sunVis = window(dayLength * 0.75, dayLength * 0.02, dayTime);
    if (sunVis > 0.0) {
        color = mix(color, renderSun(pixelCoord, color), sunVis);
    }

    return color;
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

vec3 renderMovingClouds(vec2 uv, vec3 gbColor) {
    const int CLOUD_NUM = 20;

    vec2 p = uv * u_resolution;
    vec3 color = gbColor;
    for (int i = 0; i < CLOUD_NUM; i++) {
        float size = mix(2.0, 1.0, float(i) / float(CLOUD_NUM) + 0.1 * random(vec2(float(i))));
        float speed = size * 0.25;
        float yJitter = random(vec2(float(i)));
        vec2 offset = vec2(float(i) * 200.0 + u_time * 100.0 * speed, yJitter * 500.0);
        vec2 pos = p - offset;
        pos.x = mod(pos.x, u_resolution.x);
        pos -= u_resolution * 0.5;
        color = renderCloud(pos * size, color);
    }

    return color;
}

void main() {
    vec2 uv = gl_FragCoord.xy / u_resolution;
    vec3 bg = background(uv);
    bg = renderMovingClouds(uv, bg);

    vec3 noise = vec3(
            random(gl_FragCoord.xy),
            random(gl_FragCoord.xy + vec2(1.0)),
            random(gl_FragCoord.xy + vec2(2.0))
        );
    float ditherAmount = 0.002;
    bg += noise * ditherAmount;
    bg = clamp(bg, 0.0, 1.0);

    fragColor = vec4(bg, 1.0);
}
