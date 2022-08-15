#version 300 es

precision highp float;

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform vec3 u_camera;
uniform sampler2D u_texture0;

#define PI_TWO			1.570796326794897
#define PI				3.141592653589793
#define TWO_PI			6.283185307179586


#define CAMERA_FOV 0.8
#define CAMERA_NEAR 0.00001
#define CAMERA_FAR 1000.0

#define MARCHER_STEP 128

struct Point {
    float d;
    vec3 normal;
    vec3 uvw;
};

vec2 getUv() {
	vec2 xy = gl_FragCoord.xy / u_resolution.xy;
	if (u_resolution.x > u_resolution.y) {
        xy.x *= u_resolution.x / u_resolution.y;
        xy.x += (u_resolution.y - u_resolution.x) / u_resolution.y / 2.0;
    } else {
        xy.y *= u_resolution.y / u_resolution.x;
	    xy.y += (u_resolution.x - u_resolution.y) / u_resolution.x / 2.0;
    }
	xy -= 0.5;
	return xy;
}

struct Camera {
    vec3 position;
    vec3 target;
    vec3 forward;
    vec3 right;
    vec3 up;
    float fov;
	float near;
	float far;
};
Camera getCamera(vec3 position, vec3 target) {
    vec3 forward = normalize(target - position);
    vec3 right = vec3(0.0);
    vec3 up = vec3(0.0);
	Camera camera = Camera(position, target, forward, right, up, CAMERA_FOV, CAMERA_NEAR, CAMERA_FAR);
	camera.right = normalize(vec3(camera.forward.z, 0.0, -camera.forward.x));
	camera.up = normalize(cross(camera.forward, camera.right));
	return camera;
}

/* Math 2D Transformations */
mat2 rotate2d(in float angle){
    return mat2(cos(angle),-sin(angle), sin(angle), cos(angle));
}

out vec4 outColor;

float smoothMax(in float a, in float b, in float k) {
    float h = max( k-abs(a-b), 0.0 )/k;
    return max( a, b ) + h*h*k*(1.0/4.0);
}

// polynomial smooth min
float smoothMin( float a, float b, float k )
{
    float h = max( k-abs(a-b), 0.0 )/k;
    return min( a, b ) - h*h*k*(1.0/4.0);
}

float sphere(in vec3 c, in float r) {
    return length(c) - r;
}

float box(in vec3 p, in vec3 r) {
    p = abs(p);
    vec3 v = max(p - r, 0.0);
    return length(v) - 0.005;
}

float box2d(in vec2 p, in vec2 r) {
    p = abs(p);
    vec2 v = max(p - r, 0.0);
    return length(v) - 0.005;
}

float boxCross(in vec3 p, in vec3 r) {
    p = abs(p);
    p.xz = p.z > p.x ? p.xz : p.zx;
    return length(max(p - r, 0.0));
}

float vStick(in vec3 p, in float h) {
    float d = max(p.y - h, 0.0);
    return sqrt(p.x * p.x + p.z * p.z + d * d);
}

const float gearTeethAngle = TWO_PI / 12.0;
float gearRotor(in vec3 pos) {
    
    float sector = round(atan(pos.z, pos.x) / gearTeethAngle);
    vec3 q = pos;
    q.xz = rotate2d(gearTeethAngle * sector) * q.xz;

    float d = box2d(q.xz - vec2(0.17, 0.0), vec2(0.025, 0.018));

    float d2 = abs(length(pos.xz) - 0.15) - 0.02;

    d = min(d, d2);
    
    float r = length(pos) - 0.5;
    d = smoothMax(d, abs(r) - 0.02, 0.002);

    return d;
}

vec4 gear(in vec3 pos, float offset) {
    pos.y = abs(pos.y);

    pos.xz = rotate2d(u_time * 0.1 + offset * gearTeethAngle / 2.0) * pos.xz;

    float d1 = gearRotor(pos);
    float d2 = boxCross(pos - vec3(0.0, 0.47, 0.0), vec3(0.003, 0.01, 0.18));
    float d3 = vStick(pos, 0.5) - 0.01;

    return vec4(pos, smoothMin(smoothMin(d1, d3, 0.01), d2, 0.01));
}

vec4 scene(in vec3 pos0) {
    vec3 pos = pos0;
    vec3 q = abs(pos);

    if (q.x > q.y && q.x > q.z) {
        pos = pos.yxz;
    }
    if (q.z > q.y && q.z > q.x) {
        pos = pos.yzx;
    }
    vec4 d1 = gear(pos, 0.0);

    vec3 p2 = pos0;
    
    p2 = vec3(rotate2d(-PI_TWO / 2.0) * p2.zy, p2.x);
    q = abs(p2);

    vec4 d2 = gear(p2, 1.0);

    d1 = d1.w < d2.w ? d1 : d2;

    return d1;
}

vec3 computeNormal(in vec3 pos, in float ref) {
    const vec3 s = vec3(0.001, 0.0, 0.0);

    return normalize(vec3(
        scene(pos + s.xyy).w - ref,
        scene(pos + s.yxy).w - ref,
        scene(pos + s.yyx).w - ref
    ));
}

float computeAO(in vec3 pos, in vec3 nor) {
	float occlusion = 0.0;
    float scale = 1.0;
    for (int i = 1; i < 6; i++) {
        float h = 0.03 * float(i) / 4.0;
        float d = scene(pos + h * nor).w;
        occlusion += (h - d) * scale;
        scale *= 0.95;
    }
    return 1.0 - 4.0 * occlusion;
}

Point rayMarch(in vec3 pos, in vec3 dir) {
    float distanceMoved = 0.0;
    float closest = 0.0;
    vec3 currentPos = pos;

    for (int i = 0; i < MARCHER_STEP; i++) {
        currentPos = pos + dir * distanceMoved;
        vec4 p = scene(currentPos);
        closest = p.w;
        if (closest < 0.00001) {
            return Point(
                distanceMoved,
                computeNormal(currentPos, closest),
                p.xyz
            );
        }
        distanceMoved += closest;
        if (distanceMoved > 3.0) break;
    }
    return Point(-1.0, vec3(0.0), currentPos);
}

void main() {
    vec2 st = getUv();

    Camera camera = getCamera(u_camera * 0.2, vec3(0.0));

    vec3 dir = normalize(
        camera.forward + 
        (camera.fov * camera.right * st.x) + 
        (camera.fov * camera.up * st.y)
    );

    Point p = rayMarch(camera.position, dir);

    vec3 col = vec3(1.0 + dir.y) * 0.03;

    if (p.d > 0.0) {
        vec3 pos = camera.position + p.d * dir;

        vec3 diff = texture(u_texture0, fract(p.uvw.xz * 1.0)).rgb * 0.33
                  + texture(u_texture0, fract(p.uvw.xy * 2.0)).rgb * 0.33
                  + texture(u_texture0, fract(p.uvw.zy * 3.0)).rgb * 0.33;

        diff *= diff;
        diff += 0.05;

        float light = max(p.normal.y, 0.0) * 0.5 + 0.2;
        light = computeAO(pos + 0.001 * p.normal, p.normal);

        col = p.normal; light * diff;
    }

    vec3 tot = pow(col, vec3(0.45));

    // cheap dithering
    tot += sin(gl_FragCoord.x * 114.0)*sin(gl_FragCoord.y * 211.1)/512.0;

    outColor = vec4(tot, 1.0);
}
