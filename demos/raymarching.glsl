/* Main function, uniforms & utils */

precision mediump float;

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

float opSmoothUnion(float d1, float d2, float k) {
    float h = clamp(.5 + .5 * (d2 - d1) / k, 0., 1.);
    return mix(d2, d1, h) - k * h * (1. - h);
}

float circle(vec3 st, float radius) {
    return length(st) - radius;
}
float plane(vec3 p, vec3 n, float h) {
    return dot(p, n) + h;
}

vec2 opUnion(vec2 d1, vec2 d2) {
    return (d1.x < d2.x) ? d1 : d2;
}

vec2 map(vec3 st) {
    vec2 d = vec2(1e10, 0.);

    float d1 = circle(st - vec3(0.0, 0.0, -2.0), 1.0);
    float d2 = circle(st - vec3(0.0, 0.8 + abs(sin(u_time)), -2.0), 0.5);
    float d3 = plane(st - vec3(0., -1., 0.), vec3(0., 1., 0.), .1);
    d1 = opSmoothUnion(d1, d2, .5);
    d = opUnion(d, vec2(d1, 1.));
    d = opUnion(d, vec2(d3, 2.));
    return d;
}

vec3 calcNormal(in vec3 p) {
    const float h = .0001;
    const vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h).x +
            k.yyx * map(p + k.yyx * h).x +
            k.yxy * map(p + k.yxy * h).x +
            k.xxx * map(p + k.xxx * h).x);
}

float softshadow(in vec3 ro, in vec3 rd, float mint, float maxt, float k) {
    float res = 1.;
    float t = mint;
    for (int i = 0; i < 256; i++) // 使用固定迭代次数确保编译通过
    {
        if (t >= maxt) break; // 保留原终止条件
        float h = map(ro + rd * t).x;
        if (h < .001)
            return 0.;
        res = min(res, k * h / t);
        t += h;
    }
    return res;
}

vec3 getSceneColor(vec2 fragCoord) {
    vec2 uv = fragCoord / u_resolution;
    uv = uv * 2.0 - 1.0;
    uv.x *= u_resolution.x / u_resolution.y;

    vec3 cameraPos = vec3(0., 0., 1.);
    vec3 rayDir = normalize(vec3(uv, 0.0) - cameraPos);
    vec3 col = vec3(0.0);
    vec3 lightColor = vec3(.875, .286, .333);
    vec3 objectColor = vec3(1.0);
    vec3 pointLightPos = vec3(10.0);

    float depth = 0.0;
    for (int i = 0; i < 128; i++) {
        vec3 p = cameraPos + rayDir * depth;
        // float dis = map(p);
        vec2 res = map(p);
        float d = res.x;
        float m = res.y;
        depth += d;
        if (d < 0.01) {
            vec3 normal = calcNormal(p);
            // material
            if (m == 2.) {
                lightColor = vec3(1.);
            }

            // ambient
            vec3 ambient = 0.2 * lightColor;
            col += ambient;

            // point light diffuse
            vec3 lightDirection = normalize(pointLightPos - p);
            float shading = dot(normal, lightDirection);
            shading = max(shading, 0.0);
            float shadow = softshadow(p, lightDirection, .01, 10., 16.);
            col += shading * lightColor * shadow;

            // specular
            vec3 viewDirection = normalize(vec3(cameraPos - p));
            vec3 reflectDirection = reflect(-lightDirection, normal);
            float spec = dot(viewDirection, reflectDirection);
            spec = max(spec, 0.0);
            spec = pow(spec, 20.0);
            col += spec * lightColor;

            col *= objectColor;
            break;
        }
    }
    return col;
}

void main() {
    vec3 color = vec3(0.);

    const int samples = 1; // 2x2网格采样
    float totalSamples = float(samples * samples);
    for (int y = 0; y < samples; y++) {
        for (int x = 0; x < samples; x++) {
            // 计算采样偏移量，范围[-0.5, 0.5)
            vec2 offset = (vec2(x, y) / float(samples)) - 0.5;
            color += getSceneColor(gl_FragCoord.xy + offset);
        }
    }
    color /= totalSamples;

    gl_FragColor = vec4(color, 1.0);
}
