#version 300 es

precision lowp float;

#define PI_TWO			1.570796326794897
#define PI				3.141592653589793
#define TWO_PI			6.283185307179586

#define CAMERA_FOV 0.8
#define CAMERA_NEAR 0.01
#define CAMERA_FAR 1000.0

#define MARCHER_STEP 100

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;
uniform vec3 u_camera;
uniform sampler2D u_texture0;

out vec4 outColor;


struct Point {
    float d;
    vec3 normal;
};

vec3 sunDir = normalize(vec3(1.0, 0.1, 1.0));

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

// return smoothstep and its derivative
vec2 smoothstepd( float a, float b, float x)
{
	if( x<a ) return vec2( 0.0, 0.0 );
	if( x>b ) return vec2( 1.0, 0.0 );
    float ir = 1.0/(b-a);
    x = (x-a)*ir;
    return vec2( x*x*(3.0-2.0*x), 6.0*x*(1.0-x)*ir );
}

float Rand(vec2 p) {
    p  = 310.0*fract(p * 3.3183099);
    return fract( p.x*p.y*(p.x+p.y) );
}

vec3 noised( in vec2 x ) {
    vec2 p = floor(x);
    vec2 w = fract(x);

    vec2 u = w*w*w*(w*(w*6.0-15.0)+10.0);
    vec2 du = 30.0*w*w*(w*(w-2.0)+1.0);

    float a = Rand(p+vec2(0,0));
    float b = Rand(p+vec2(1,0));
    float c = Rand(p+vec2(0,1));
    float d = Rand(p+vec2(1,1));

    float k0 = a;
    float k1 = b - a;
    float k2 = c - a;
    float k4 = a - b - c + d;

    float val = -1.0 + 2.0 * (k0 + k1 * u.x + k2 * u.y + k4 * u.x * u.y);

    return vec3(
        val,
        2.0 * du * vec2(
            k1 + k4 * u.y,
            k2 + k4 * u.x
        )
    );
}

float noise(in vec2 x) {
    vec2 p = floor(x);
    vec2 w = fract(x);
    
    vec2 u = w*w*w*(w*(w*6.0-15.0)+10.0);

    float a = Rand(p+vec2(0,0));
    float b = Rand(p+vec2(1,0));
    float c = Rand(p+vec2(0,1));
    float d = Rand(p+vec2(1,1));
    
    return -1.0+2.0*(a + (b-a)*u.x + (c-a)*u.y + (a - b - c + d)*u.x*u.y);
}


vec3 fd(in vec2 p) {

    const float ZOOM = 6.0;
    const mat2 Rot  = mat2(4.0 / 5.0, -3.0 / 5.0,  3.0 / 5.0,  4.0 / 5.0);
    const mat2 RotI = mat2(4.0 / 5.0,  3.0 / 5.0, -3.0 / 5.0,  4.0 / 5.0);
    mat2 m = mat2(1.0, 0.0, 0.0, 1.0);
    p /= ZOOM;
    float G = 0.4;
    float height = 0.0;
    vec2 derivative;

    float amplitude = 2.0;
    float scale = 1.0;
    for (int i = 0; i < 8; i++) {
        vec3 n = noised(p * scale);
        derivative += amplitude * m * n.yz;
        height += amplitude * n.x;
        amplitude *= G;
        scale *= 2.0;
        p = Rot * p;
        m = 2.0 * RotI * m;
    }

    // y.x += smoothstep(0.35, 0.55, y)

    return vec3(height, derivative);
}

vec4 terrain(in vec3 pos) {
    vec3 p = fd(pos.xz);
    float height = p.x;
    
    vec3 normal = normalize(vec3(-p.y, 1.0, -p.z));

    return vec4(height, normal);
}

vec4 scene(in vec3 pos) {
    vec4 d = terrain(pos);
    return d;
}

/* vec3 computeNormal(in vec3 pos, in float ref) {
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
} */

float rayMarchShadow(in vec3 pos) {
    float res = 1.0;
    float t = 0.0;

    for( int i=0; i<32; i++ )
    {
        vec3  pos = pos + t * vec3(1.0, 0.0, 0.0);
        float y = scene( pos ).x;
        float hei = pos.y - y;
        res = min( res, 32.0*hei/t );
        if( res<.01 || pos.y>5.0 ) break;
        t += clamp( hei, 2.0+t*0.1, 100.0 );
    }

    return clamp( res, 0.0, 1.0 );
}

Point rayMarch(in vec3 pos, in vec3 dir) {
    float distanceMoved = 0.0;
    float closest = 0.0;
    vec3 currentPos = pos;
    Point result;

    for (int i = 0; i < MARCHER_STEP; i++) {
        currentPos = pos + dir * distanceMoved;
        vec4 p = scene(currentPos);
        closest = currentPos.y - p.x;

        if (closest < 0.01) {
            vec3 normal = p.yzw;
            result = Point(
                distanceMoved,
                normal
            );
            break;
        }
        distanceMoved += closest;
        if (distanceMoved > 2000.0) break;
    }

    return result;
}

void main() {
    vec2 st = getUv();
    
    vec3 moveDir = vec3(0.1, 0.0, 0.2) * 0.0;
    vec3 cameraPos = u_camera + moveDir - vec3(0.0, 1.0, 0.0);
    vec3 cameraTarget = vec3(0.0, 1.0, 0.0) + moveDir;
    Camera camera = getCamera(cameraPos, cameraTarget);

    vec3 dir = normalize(
        camera.forward + 
        (camera.fov * camera.right * st.x) + 
        (camera.fov * camera.up * st.y)
    );

    Point p = rayMarch(camera.position, dir);

    vec3 col = vec3(1.0 + dir.y) * 0.03;

    if (p.d > 0.0) {
        vec3 pos = camera.position + dir * p.d;
        float shadow = rayMarchShadow(pos);
        float isInLight = 1.0 - shadow * 0.5;
        float light = 0.01;
        light += isInLight * 0.3; // * max(dot(p.normal, sunDir), 0.0);
        light += max(0.0, pos.y + 1.0) * 0.2;
        col += shadow * vec3(1.0);
 
        col = mix(col, vec3(1.00, 0.0, 0.0), step(abs(pos.y - 4.0), 0.01));
    }

    vec3 tot = pow(col, vec3(0.45));

    // cheap dithering
    tot += sin(gl_FragCoord.x * 114.0)*sin(gl_FragCoord.y * 211.1)/512.0;

    outColor = vec4(tot, 1.0);
}
