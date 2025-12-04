#version 300 es
precision mediump float;

uniform vec2 u_resolution;
uniform float u_time;

out vec4 fragColor;

const float DayLength = 10.0;
const float LightDayLength = DayLength * 0.5;
const float SunMoonRiseSetInterval = DayLength * 0.05;

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

float random(vec2 a) {
    float t = dot(a, vec2(36.5323, 73.945));
    return sin(t);
}

vec3 renderSun(vec2 p, vec3 bgColor, float dayTime) {
    vec2 dropDistance = vec2(0.0, 500.0);
    vec2 centerBase = vec2(200.0, u_resolution.y * 0.8);

    vec2 center;
    float sunsetStart = LightDayLength - SunMoonRiseSetInterval;
    if (sunsetStart <= dayTime) {
        // sun set
        float t = smoothstep(sunsetStart, LightDayLength, dayTime);
        center = centerBase + mix(vec2(0.0), dropDistance, t);
    } else {
        // sun rise
        float t = smoothstep(0.0, SunMoonRiseSetInterval, dayTime);
        center = centerBase + mix(dropDistance, vec2(0.0), t);
    }

    float radius = 100.0;
    float d = sdfCircle(p - center, radius);

    vec3 sunColor = vec3(0.84, 0.62, 0.26);
    vec3 haloColor = vec3(0.9, 0.85, 0.47);

    // the larger the haloIntensity, the smaller the halo
    float haloIntensity = 0.05;
    float halo = exp(-max(d, 0.0) * haloIntensity);

    vec3 color = bgColor + haloColor * halo;
    color = mix(sunColor, color, step(0.0, d));
    return color;
}

float sdfMoon(vec2 p) {
    float bigCircle = sdfCircle(p, 100.0);
    float smallCircle = sdfCircle(p + vec2(50.0, 0.0), 70.0);
    return opSubtraction(bigCircle, smallCircle);
}

vec3 renderMoon(vec2 p, vec3 bgColor, float dayTime) {
    vec2 dropDistance = vec2(0.0, 500.0);
    vec2 centerBase = vec2(u_resolution.x - 200.0, u_resolution.y * 0.8);

    vec2 center;
    float moonriseEnd = LightDayLength + SunMoonRiseSetInterval;
    if (moonriseEnd >= dayTime) {
        // moon rise
        float t = smoothstep(LightDayLength, moonriseEnd, dayTime);
        center = centerBase + mix(dropDistance, vec2(0.0), t);
    } else {
        // moon set
        float t = smoothstep(DayLength - SunMoonRiseSetInterval, DayLength, dayTime);
        center = centerBase + mix(vec2(0.0), dropDistance, t);
    }

    float d = sdfMoon(p - center);

    vec3 moonColor = vec3(1.0, 0.0, 0.0);

    return mix(moonColor, bgColor, step(0.0, d));
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

    float dayTime = mod(u_time, DayLength);
    vec3 color;

    if (dayTime < DayLength * 0.25) {
        color = mix(morning, midday, smoothstep(0.0, DayLength * 0.25, dayTime));
    } else if (dayTime < LightDayLength) {
        color = mix(midday, evening, smoothstep(DayLength * 0.25, LightDayLength, dayTime));
    } else if (dayTime < DayLength * 0.75) {
        color = mix(evening, night, smoothstep(LightDayLength, DayLength * 0.75, dayTime));
    } else {
        color = mix(night, morning, smoothstep(DayLength * 0.75, DayLength, dayTime));
    }

    vec2 pixelCoord = uv * u_resolution;
    if (dayTime <= LightDayLength) {
        color = renderSun(pixelCoord, color, dayTime);
    } else {
        color = renderMoon(pixelCoord, color, dayTime);
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
