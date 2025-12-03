#version 300 es
precision mediump float;

in vec4 v_position;
in vec4 v_normal;

uniform vec3 u_camera;

out vec4 fragColor;

const vec3 u_lightPos = vec3(10.0); // 默认灯光位置
const vec3 u_lightColor = vec3(1.0); // 默认灯光颜色
const vec3 u_baseColor = vec3(0.5); // 默认基础颜色

// 优化后的环境光函数
vec3 ambientLight(vec3 lightColor) {
    return lightColor * 0.2; // 降低环境光强度，让卡通效果更明显
}

// 优化后的点光源函数
vec3 pointLight(vec3 lightPos, vec3 lightColor) {
    vec3 normal = normalize(v_normal.xyz);
    vec3 lightDirection = normalize(lightPos - v_position.xyz);

    // 漫反射计算
    float diff = max(dot(normal, lightDirection), 0.0);

    // 使用内置reflect函数，更高效
    vec3 viewDirection = normalize(u_camera - v_position.xyz);
    vec3 lightReflection = reflect(-lightDirection, normal);
    float spec = pow(max(dot(lightReflection, viewDirection), 0.0), 64.0); // 增加高光指数

    // 改进的卡通渲染阈值
    // 漫反射：3级卡通化
    if (diff > 0.8) {
        diff = 1.0;
    } else if (diff > 0.4) {
        diff = 0.6;
    } else if (diff > 0.1) {
        diff = 0.3;
    } else {
        diff = 0.0;
    }

    // 高光：2级卡通化
    if (spec > 0.7) {
        spec = 1.0;
    } else if (spec > 0.3) {
        spec = 0.5;
    } else {
        spec = 0.0;
    }

    return lightColor * (diff + spec * 0.8); // 降低高光强度
}

void main() {
    // 使用uniform参数，提供更好的灵活性
    vec3 baseColor = u_baseColor;
    vec3 lightColor = u_lightColor;
    vec3 lightPos = u_lightPos;

    vec3 light = vec3(0.0);
    light += ambientLight(lightColor);
    light += pointLight(lightPos, lightColor);

    // 确保颜色不会过亮
    light = min(light, vec3(1.0));

    fragColor = vec4(baseColor * light, 1.0);
}
