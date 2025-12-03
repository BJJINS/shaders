#version 300 es
precision mediump float;

out vec4 fragColor; // 着色器输出颜色

uniform vec2 u_resolution;
uniform float u_time;

vec3 rayOrigin = vec3(0.0, 5.0, 3.0); // 相机位置
vec3 target = vec3(0.0, 0.0, -5.0); // 射线目标点
vec3 backgroundColor = vec3(0.1, 0.1, 0.2);
vec4 groundPlane = vec4(0.0, 1.0, 0.0, 1.0); // y=1.0 的平面（法线向上，偏移量为1.0）
vec3 groundColor = vec3(1.0); // 地面颜色
vec3 lightColor = vec3(1.0);
vec3 lightPos = vec3(5.0, 5.0, -4.0);

struct HitObject {
    vec3 color;
    vec3 normal;
    float t;
    int type;
    float specularPower;
};

struct Sphere {
    vec3 center;
    vec3 color;
    float radius;
    float specularPower;
};

struct HitSphere {
    Sphere sphere;
    vec3 normal;
    float closetT;
};
Sphere spheres[2] = Sphere[2](
        Sphere(vec3(2.0, 0.0, -8.0), vec3(.875, .286, .333), 1.0, 10.0),
        Sphere(vec3(-2.0, 0.0, -8.0), vec3(0.192, 0.439, 0.651), 1.0, 5.0)
    );

/**
 * 球体相交检测
 * @param rayOrigin 射线原点
 * @param rayDirection 射线方向
 * @param sphere 球体
 * @return vec2 交点参数 t1, t2。
 */
vec2 sphIntersect(in vec3 rayOrigin, in vec3 rayDirection, in Sphere sphere) {
    vec3 oc = rayOrigin - sphere.center;
    float b = dot(oc, rayDirection);
    float c = dot(oc, oc) - sphere.radius * sphere.radius;
    float h = b * b - c;
    if (h < 0.0) return vec2(-1.0); // 无交点
    h = sqrt(h);
    return vec2(-b - h, -b + h);
}

HitSphere intersectSpheres(in vec3 rayOrigin, in vec3 rayDirection, float minT, float maxT) {
    HitSphere hitSphere;
    hitSphere.closetT = maxT;
    for (int i = 0; i < 2; i++) {
        Sphere sphere = spheres[i];
        vec2 ts = sphIntersect(rayOrigin, rayDirection, sphere);
        if (ts.x > minT && ts.x < maxT && ts.x < hitSphere.closetT) {
            hitSphere.closetT = ts.x;
            hitSphere.sphere = sphere;
        }
        if (ts.y > minT && ts.y < maxT && ts.y < hitSphere.closetT) {
            hitSphere.closetT = ts.y;
            hitSphere.sphere = sphere;
        }
    }

    if (hitSphere.closetT < maxT) {
        hitSphere.normal = normalize(vec3(rayOrigin + rayDirection * hitSphere.closetT - hitSphere.sphere.center));
    }

    return hitSphere;
}

// ============== 立方体 ==============
struct Box {
    vec3 center;
    vec3 color;
    vec3 size;
    float specularPower;
};

struct HitBox {
    Box box;
    vec3 normal;
    float closetT;
};

Box boxes[1] = Box[1](
        Box(vec3(0.0, 0.0, -5.0), vec3(1.0, 0.8, 0.2), vec3(0.5), 2.0)
    );

/**
 * 立方体相交检测
 * @param ro 射线原点
 * @param rd 射线方向
 * @param boxSize 立方体大小
 * @param outNormal 输出参数，存储交点处的法向量
 * @return mat2x3 交点参数 t1, t2。
 */
mat2x3 boxIntersect(vec3 ro, vec3 rd, vec3 boxSize) {
    vec3 m = 1.0 / rd;
    vec3 n = m * ro;
    vec3 k = abs(m) * boxSize;
    vec3 t1 = -n - k;
    vec3 t2 = -n + k;
    float tN = max(max(t1.x, t1.y), t1.z);
    float tF = min(min(t2.x, t2.y), t2.z);
    vec3 normal = vec3(0.0);
    if (tN > tF || tF < 0.0) return mat2x3(vec3(-1.0), normal);
    normal = (tN > 0.0) ? step(vec3(tN), t1) : step(t2, vec3(tF));
    normal *= -sign(rd);
    return mat2x3(vec3(tN, tF, -1.0), normal);
}

HitBox intersectBoxes(in vec3 rayOrigin, in vec3 rayDirection, float minT, float maxT) {
    HitBox hitBox;
    hitBox.closetT = maxT;
    Box closetBox;
    for (int i = 0; i < 1; i++) {
        Box box = boxes[i];
        vec3 localRo = rayOrigin - box.center; // 转换到立方体局部坐标
        // 修改为绕y轴旋转的矩阵
        mat3x3 rotationMatrix = mat3x3(
                cos(u_time), 0.0, sin(u_time),
                0.0, 1.0, 0.0,
                -sin(u_time), 0.0, cos(u_time)
            );
        localRo = rotationMatrix * localRo;
        vec3 rotatedRayDir = rotationMatrix * rayDirection;
        mat2x3 t = boxIntersect(localRo, rotatedRayDir, box.size);
        if (t[0].x > minT && t[0].x < maxT && t[0].x < hitBox.closetT) {
            hitBox.closetT = t[0].x;
            hitBox.box = box;
            // 将法线从局部坐标系转换回世界坐标系
            hitBox.normal = transpose(rotationMatrix) * t[1];
        }
        if (t[0].y > minT && t[0].y < maxT && t[0].y < hitBox.closetT) {
            hitBox.closetT = t[0].y;
            hitBox.box = box;
            // 将法线从局部坐标系转换回世界坐标系
            hitBox.normal = transpose(rotationMatrix) * t[1];
        }
    }
    return hitBox;
}

/**
 * 平面相交 地面 或者 墙面
 * @param {vec3} ro 光线起点
 * @param {vec3} rd 光线方向
 * @param {vec4} p 平面参数 p.xyz 平面法向量 p.w 平面常量
 * @returns {float} 相交解t
 */
float plaIntersect(vec3 ro, vec3 rd, vec4 p) {
    return -(dot(ro, p.xyz) + p.w) / dot(rd, p.xyz);
}

/**
 * 地面相交
 * @param {vec3} rayOrigin 光线起点
 * @param {vec3} rayDirection 光线方向
 * @param {float} minT 最小相交解
 * @param {float} maxT 最大相交解
 * @returns {vec4} xyz 法线 w 相交解
 */
vec4 intersectGroundPlane(in vec3 rayOrigin, in vec3 rayDirection, float minT, float maxT) {
    float t = plaIntersect(rayOrigin, rayDirection, groundPlane);
    if (t > minT && t < maxT) {
        vec3 hitPoint = rayOrigin + rayDirection * t;
        if (abs(hitPoint.x) < 8.0 && abs(hitPoint.z) < 20.0) {
            return vec4(groundPlane.xyz, t);
        }
    }
    return vec4(0.0, 0.0, 0.0, -1.0);
}

// 环境光
vec3 ambientLight(vec3 color, float intensity) {
    return color * intensity;
}

/**
    点光源
    color: 光源颜色
    intensity: 光源强度
    position: 光源位置
    hitPoint: 交点位置 | 顶点位置
    normal: 交点法线
    viewDirection: 视线防线，相机位置-交点位置
    specularPower: 高光反射指数
    decayPower: 衰减指数
*/
vec3 pointLight(vec3 color, float intensity, vec3 position, vec3 hitPoint, vec3 normal, vec3 viewDirection, float specularPower, float decayPower) {
    vec3 lightDir = normalize(position - hitPoint);
    float distance = length(position - hitPoint);

    // 漫反射
    float diff = max(dot(normal, lightDir), 0.0);

    // 高光反射
    vec3 reflectDir = reflect(-lightDir, normal);
    float spec = pow(max(dot(viewDirection, reflectDir), 0.0), specularPower);

    // 衰减
    float attenuation = 1.0 / (1.0 + decayPower * distance);

    return color * intensity * attenuation * (diff + spec);
}

vec3 createRay(vec3 rayOrigin, vec3 target, float d) {
    vec2 uv = (gl_FragCoord.xy * 2.0 - u_resolution.xy) / u_resolution.y;
    vec3 view = normalize(target - rayOrigin); // 视线方向
    vec3 direction = normalize(vec3(uv, d));
    // 计算相机的坐标系
    vec3 up = vec3(0.0, 1.0, 0.0);
    vec3 right = normalize(cross(view, up));
    up = normalize(cross(right, view));
    // 根据视线方向旋转视口
    mat3 viewProjectionMatrix = mat3(
            right,
            up,
            view
        );
    return viewProjectionMatrix * direction;
}

vec3 raytracing(in vec3 rayOrigin, in vec3 rayDirection) {
    // dis表示视口到相机的位置，检查相交的解必须大于dis
    // 如果小于等于dis，表示射线和球体的交点在视口到相机的一侧
    float minT = 1.0;
    float maxT = 1000000.0;
    vec3 finalColor = backgroundColor;
    HitObject hitObject = HitObject(vec3(0.0), vec3(0.0), 0.0, -1, -1.0);

    HitSphere hitSphere = intersectSpheres(rayOrigin, rayDirection, minT, maxT);
    if (hitSphere.closetT < maxT) {
        maxT = hitSphere.closetT;
        hitObject = HitObject(
                hitSphere.sphere.color,
                hitSphere.normal,
                hitSphere.closetT,
                0,
                hitSphere.sphere.specularPower
            );
    }

    vec4 hitGroundPlane = intersectGroundPlane(rayOrigin, rayDirection, minT, maxT);
    if (hitGroundPlane.w > minT && hitGroundPlane.w < maxT) {
        maxT = hitGroundPlane.w;
        hitObject = HitObject(
                groundColor,
                hitGroundPlane.xyz,
                hitGroundPlane.w,
                1,
                -1.0
            );
    }

    HitBox hitBox = intersectBoxes(rayOrigin, rayDirection, minT, maxT);
    if (hitBox.closetT < maxT) {
        hitObject = HitObject(
                hitBox.box.color,
                hitBox.normal,
                hitBox.closetT,
                2,
                hitBox.box.specularPower
            );
    }

    if (hitObject.type > -1) {
        vec3 hitPoint = rayOrigin + rayDirection * hitObject.t;
        if (hitObject.type == 1) {
            return hitObject.color;
        }

        vec3 ambient = ambientLight(lightColor, .5);
        vec3 pointLight = pointLight(lightColor, 2.0, lightPos, hitPoint, hitObject.normal, -rayDirection, hitObject.specularPower, 0.3);
        finalColor = (ambient + pointLight) * hitObject.color;
    }

    return finalColor;
}

void main() {
    vec3 rayDirection = createRay(rayOrigin, target, 2.0);
    fragColor = vec4(raytracing(rayOrigin, rayDirection), 1.0);
}