#version 300 es

precision highp float;

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform vec3 u_camera;

#define PI_TWO			1.570796326794897
#define PI				3.141592653589793
#define TWO_PI			6.283185307179586


#define CAMERA_FOV 0.8
#define CAMERA_NEAR 0.00001
#define CAMERA_FAR 1000.0

#define MARCHER_STEP 128	

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

float gear(in vec3 pos) {
    const float angle = TWO_PI / 12.0;
    float sector = round(atan(pos.z, pos.x) / angle);
    vec3 q = pos;
    q.xz = rotate2d(angle * sector) * q.xz;

    float d = box2d(q.xz - vec2(0.2, 0.0), vec2(0.04, 0.02));

    float d2 = abs(length(pos.xz) - 0.18) - 0.02;

    d = min(d, d2);

    d = smoothMax(d, abs(pos.y) - 0.03, 0.004);

    return d;
}


float scene(in vec3 pos) {
    float rs = u_time / 10.0;

    vec3 p1 = pos;
    p1.xz = rotate2d(rs) * p1.xz;
    float gear1 = gear(p1);

    vec3 p2 = pos;
    p2.x += 0.45;
    p2.xz = rotate2d(-rs+0.24) * p2.xz;
    float gear2 = gear(p2);
    
    return min(gear1, gear2);
}

vec3 computeNormal(in vec3 pos, in float ref) {
    const vec3 s = vec3(0.001, 0.0, 0.0);

    return normalize(vec3(
        scene(pos + s.xyy) - ref,
        scene(pos + s.yxy) - ref,
        scene(pos + s.yyx) - ref
    ));
}

vec3 rayMarch(in vec3 pos, in vec3 dir) {
    float distanceMoved = 0.0;
    for (int i = 0; i < MARCHER_STEP; i++) {
        vec3 currentPos = pos + dir * distanceMoved;
        float closest = scene(currentPos);
        if (closest < 0.001) {
            return computeNormal(currentPos, closest);
        }
        distanceMoved += closest;
    }
    return vec3(0.0);
}

void main() {
    vec2 st = getUv();

    Camera camera = getCamera(u_camera * 0.1, vec3(0.0));

    vec3 dir = normalize(
        camera.forward + 
        (camera.fov * camera.right * st.x) + 
        (camera.fov * camera.up * st.y)
    );

    vec3 normal = rayMarch(camera.position, dir);

    float l = length(normal);

    outColor = vec4(normal / 3.0 + 0.4 * l + smoothstep(dir.y, 0.9, 0.0) / 4.0, 1.0);
}
