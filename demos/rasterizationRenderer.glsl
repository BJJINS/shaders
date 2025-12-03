#version 300 es
precision mediump float;

uniform vec2 u_resolution;
uniform float u_time;

out vec4 fragColor;

#define LINE_WIDTH 0.01
#define RED vec3(1.0,0.0,0.0)
#define GREEN vec3(0.0,1.0,0.0)
#define BLUE vec3(0.0,0.0,1.0)
#define BACKGROUND_COLOR vec3(0.0)
#define CAMERA_VIEWPORT_DIS 5.0

// 精度误差容限
const float EPSILON = 1e-6;

// 计算UV坐标
vec2 getUV() {
    return 5.0 * (gl_FragCoord.xy - u_resolution.xy * 0.5) / u_resolution.y;
}

// 平移矩阵
mat4 createTranslationMat(float x, float y, float z) {
    return mat4(
        1.0, 0.0, 0.0, 0.0,
        0.0, 1.0, 0.0, 0.0,
        0.0, 0.0, 1.0, 0.0,
        x, y, z, 1.0
    );
}

// 旋转矩阵
mat4 createRotationMat(float angle, vec3 axis) {
    // 归一化旋转轴向量
    axis = normalize(axis);
    float c = cos(angle);
    float s = sin(angle);
    float t = 1.0 - c;
    float x = axis.x;
    float y = axis.y;
    float z = axis.z;
    return mat4(
        t * x * x + c, t * x * y - z * s, t * x * z + y * s, 0.0,
        t * x * y + z * s, t * y * y + c, t * y * z - x * s, 0.0,
        t * x * z - y * s, t * y * z + x * s, t * z * z + c, 0.0,
        0.0, 0.0, 0.0, 1.0
    );
}

mat4 createViewMatrix() {
    vec3 cameraPos = vec3(10.0, 0.0, -10.0);
    vec3 lookAt = vec3(0.0, 0.0, 1.0);
    vec3 up = vec3(0.0, 1.0, 0.0);

    vec3 forward = normalize(lookAt - cameraPos);
    vec3 right = normalize(cross(up, forward));
    vec3 cameraUp = normalize(cross(forward, right));

    // 修复了相机矩阵计算
    mat4 translation = createTranslationMat(-cameraPos.x, -cameraPos.y, -cameraPos.z);
    mat4 rotation = mat4(
            right.x, cameraUp.x, forward.x, 0.0,
            right.y, cameraUp.y, forward.y, 0.0,
            right.z, cameraUp.z, forward.z, 0.0,
            0.0, 0.0, 0.0, 1.0
        );

    // 视图矩阵的核心逻辑是 “先平移、后旋转”
    return rotation * translation;
}

// 透视投影 - 简化和修复计算
vec2 perspectiveProjection(vec3 p) {
    // 简化的透视投影，确保z>0
    float z = max(0.1, p.z);
    return vec2(
        CAMERA_VIEWPORT_DIS * p.x / z,
        CAMERA_VIEWPORT_DIS * p.y / z
    );
}

bool pointInTriangle(vec2 a, vec2 b, vec2 c, vec2 p) {
    vec2 v0 = c - a;
    vec2 v1 = b - a;
    vec2 v2 = p - a;

    // 计算点积
    float dot00 = dot(v0, v0);
    float dot01 = dot(v0, v1);
    float dot02 = dot(v0, v2);
    float dot11 = dot(v1, v1);
    float dot12 = dot(v1, v2);

    float denom = dot00 * dot11 - dot01 * dot01;

    // 处理退化三角形（面积接近0）
    if (abs(denom) < EPSILON) {
        return false;
    }
    float u = (dot11 * dot02 - dot01 * dot12) / denom;
    float v = (dot00 * dot12 - dot01 * dot02) / denom;

    // 检查点是否在三角形内
    // 判断条件：u ≥ 0, v ≥ 0, u + v ≤ 1（允许微小误差）
    return (u > -EPSILON) && (v > -EPSILON) && (u + v < 1.0 + EPSILON);
}

// 画线函数
vec3 drawLine(vec2 p0, vec2 p1, vec2 p, vec3 color) {
    float a = p1.y - p0.y;
    float b = p0.x - p1.x;
    float c = p1.x * p0.y - p0.x * p1.y;

    float lineLengthSquared = (p1.x - p0.x) * (p1.x - p0.x) + (p1.y - p0.y) * (p1.y - p0.y);
    float dist = abs(a * p.x + b * p.y + c) / sqrt(a * a + b * b);
    float dotProduct = dot(p - p0, p1 - p0);

    if (dotProduct >= 0.0 && dotProduct <= lineLengthSquared && dist < LINE_WIDTH / 2.0) {
        return color;
    }

    return vec3(0.0);
}

vec3 drawTriangle(vec2 p0, vec2 p1, vec2 p2, vec2 p, vec3 color) {
    bool isInTriangle = pointInTriangle(p0, p1, p2, p);
    if (isInTriangle) {
        return color;
    }
    return BACKGROUND_COLOR;
}

// 绘制三角形（线框）
vec3 drawTriangleWireframe(vec2 p0, vec2 p1, vec2 p2, vec2 p, vec3 color) {
    return drawLine(p0, p1, p, color) +
        drawLine(p1, p2, p, color) +
        drawLine(p0, p2, p, color);
}

// 绘制立方体 - 修复了相机位置和剔除逻辑
vec3 drawCube(vec3 center, float size, mat4 modelMatrix, vec2 p, bool wireframe) {
    mat4 viewMatrix = createViewMatrix();
    mat4 translate = createTranslationMat(center.x, center.y, center.z);
    modelMatrix = translate * modelMatrix;
    mat4 viewModelMatrix = viewMatrix * modelMatrix;

    // 立方体顶点定义
    vec4 vertexes[8] = vec4[8](
            viewModelMatrix * vec4(-size, size, -size, 1.0), // 0
            viewModelMatrix * vec4(size, size, -size, 1.0), // 1
            viewModelMatrix * vec4(-size, -size, -size, 1.0), // 2
            viewModelMatrix * vec4(size, -size, -size, 1.0), // 3
            viewModelMatrix * vec4(-size, size, size, 1.0), // 4
            viewModelMatrix * vec4(size, size, size, 1.0), // 5
            viewModelMatrix * vec4(-size, -size, size, 1.0), // 6
            viewModelMatrix * vec4(size, -size, size, 1.0) // 7
        );

    // 修复立方体索引
    ivec3 triangles[12] = ivec3[12](
            ivec3(0, 1, 2), // 前面
            ivec3(1, 2, 3),
            ivec3(4, 5, 6), // 后面
            ivec3(5, 6, 7),
            ivec3(0, 4, 6), // 左面
            ivec3(0, 6, 2),
            ivec3(1, 5, 7), // 右面
            ivec3(1, 7, 3),
            ivec3(2, 3, 7), // 下面
            ivec3(2, 7, 6),
            ivec3(0, 1, 5), // 上面
            ivec3(0, 5, 4)
        );

    vec3 cubeColor = vec3(0.0);

    // 暂时移除背面剔除，确保能看到所有面
    for (int i = 0; i < triangles.length(); i++) {
        ivec3 t = triangles[i];
        vec3 p0 = vertexes[t.x].xyz;
        vec3 p1 = vertexes[t.y].xyz;
        vec3 p2 = vertexes[t.z].xyz;

        // 应用透视投影，检查z值是否有效
        if (p0.z > 0.1 && p1.z > 0.1 && p2.z > 0.1) {
            vec2 p0_2d = perspectiveProjection(p0);
            vec2 p1_2d = perspectiveProjection(p1);
            vec2 p2_2d = perspectiveProjection(p2);

            // 为不同的面使用不同的颜色
            vec3 faceColor;
            if (i < 2) faceColor = RED; // 前面
            else if (i < 4) faceColor = GREEN; // 后面
            else if (i < 6) faceColor = BLUE; // 左面
            else if (i < 8) faceColor = RED; // 右面
            else if (i < 10) faceColor = GREEN; // 下面
            else faceColor = BLUE; // 上面
            if (wireframe) {
                cubeColor += drawTriangleWireframe(p0_2d, p1_2d, p2_2d, p, faceColor);
            } else {
                cubeColor += drawTriangle(p0_2d, p1_2d, p2_2d, p, faceColor);
            }
        }
    }

    return cubeColor;
}

void main() {
    vec2 uv = getUV();

    // 简化动画，确保基本功能正常
    float rotationAngle = u_time * 0.5;
    mat4 rotationMat = createRotationMat(rotationAngle, vec3(1.0, 1.0, 1.0));

    // 绘制场景
    vec3 color = BACKGROUND_COLOR;
    color += drawCube(vec3(0.0, 0.0, 0.0), 0.8, rotationMat, uv, false);
    fragColor = vec4(color, 1.0);
}
