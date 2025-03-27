precision highp float;

uniform vec2 u_resolution;
uniform vec2 u_mouse;
uniform float u_time;

#define PI_TWO			1.570796326794897
#define PI				3.141592653589793
#define TWO_PI			6.283185307179586
#define INF             1e10

/* Coordinate and unit utils */
vec2 coord(in vec2 p) {
    p = p / u_resolution.xy;
    // correct aspect ratio
    if (u_resolution.x > u_resolution.y) {
        p.x *= u_resolution.x / u_resolution.y;
        p.x += (u_resolution.y - u_resolution.x) / u_resolution.y / 2.0;
    } else {
        p.y *= u_resolution.y / u_resolution.x;
        p.y += (u_resolution.x - u_resolution.y) / u_resolution.x / 2.0;
    }
    // centering
    p -= 0.5;
    p *= vec2(-1.0, 1.0);
    return p;
}
#define rx 1.0 / min(u_resolution.x, u_resolution.y)
#define uv gl_FragCoord.xy / u_resolution.xy
// #define st coord(gl_FragCoord.xy)
#define mx coord(u_mouse)

/* Math 3D Transformations */

const mat4 projection = mat4(
    vec4(3.0 / 4.0, 0.0, 0.0, 0.0),
    vec4(     0.0, 1.0, 0.0, 0.0),
    vec4(     0.0, 0.0, 0.5, 0.5),
    vec4(     0.0, 0.0, 0.0, 1.0)
);

mat4 scale = mat4(
    vec4(4.0 / 3.0, 0.0, 0.0, 0.0),
    vec4(     0.0, 1.0, 0.0, 0.0),
    vec4(     0.0, 0.0, 1.0, 0.0),
    vec4(     0.0, 0.0, 0.0, 1.0)
);

mat4 rotation = mat4(
    vec4(1.0,          0.0,         0.0, 	0.0),
    vec4(0.0,  cos(u_time), sin(u_time),  	0.0),
    vec4(0.0, -sin(u_time), cos(u_time),  	0.0),
    vec4(0.0,          0.0,         0.0, 	1.0)
);

mat4 rotationAxis(float angle, vec3 axis) {
    axis = normalize(axis);
    float s = sin(angle);
    float c = cos(angle);
    float oc = 1.0 - c;
    return mat4(oc * axis.x * axis.x + c,           oc * axis.x * axis.y - axis.z * s,  oc * axis.z * axis.x + axis.y * s,  0.0,
                oc * axis.x * axis.y + axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z - axis.x * s,  0.0,
                oc * axis.z * axis.x - axis.y * s,  oc * axis.y * axis.z + axis.x * s,  oc * axis.z * axis.z + c,           0.0,
                0.0,                                0.0,                                0.0,                                1.0);
}

vec3 rotateX(vec3 p, float angle) {
    mat4 rmy = rotationAxis(angle, vec3(1.0, 0.0, 0.0));
    return (vec4(p, 1.0) * rmy).xyz;
}

vec3 rotateY_(vec3 p, float angle) {
    mat4 rmy = rotationAxis(angle, vec3(0.0, 1.0, 0.0));
    return (vec4(p, 1.0) * rmy).xyz;
}

vec3 rotateZ(vec3 p, float angle) {
    mat4 rmy = rotationAxis(angle, vec3(0.0, 0.0, 1.0));
    return (vec4(p, 1.0) * rmy).xyz;
}

vec3 rotateY(vec3 p, float angle) {
    float c = cos(angle);
    float s = sin(angle);
    mat4 r = mat4(
        vec4(c, 0, s, 0),
        vec4(0, 1, 0, 0),
        vec4(-s, 0, c, 0),
        vec4(0, 0, 0, 1)
    );
    return (vec4(p, 1.0) * r).xyz;
}

float sdSphere(vec3 p, vec3 c, float r) {
    return length(p - c) - r;
}

float sdGround(vec3 p) {
    return p.y;
}

float sdBox(vec3 p, vec3 b) {
    vec3 d = abs(p) - b;
    return min(max(d.x, max(d.y, d.z)), 0.0) + length(max(d, 0.0));
}

float sdCross(vec3 p) {
  float da = sdBox(p.xyz,vec3(INF,1.0,1.0));
  float db = sdBox(p.yzx,vec3(1.0,INF,1.0));
  float dc = sdBox(p.zxy,vec3(1.0,1.0,INF));
  return min(da,min(db,dc));
}

vec3 round(vec3 p) {
    return sign(p)*floor(abs(p)+0.5);
}

vec4 getScene(vec3 p0) {
    // p = rotateX(p, sin(p.y * 0.5));
    vec3 id0 = round(p0/2.1);
    vec3 p = p0 - 2.1*id0;
    vec3 id = mod(id0, 3.0) / 3.0;

    float d = sdBox(p,vec3(1.0));
    vec4 res = vec4( 0.0, 0.0, 0.0, d );

    float S1 = 2.85 + id.x * 0.5;
    float S2 = 2.85 + id.z * 0.5;//+ sin(u_time);

    const int ITERATIONS = 6;

    
	
    float s = 1.0;
    for(int m=0; m < ITERATIONS; m++) {

        vec3 a = mod( p*s, 2.0 )-1.0;
        s *= S1;
        vec3 r = abs(1.0 - S2*abs(a));
        float da = max(r.x,r.y);
        float db = max(r.y,r.z);
        float dc = max(r.z,r.x);
        float c = (min(da,min(db,dc))-1.0)/s;

        p.x += 1.;

        if( c>d )
        {
          d = c;
          res = vec4( id.x, da*db*dc * 0.2, 1.0 - (float(m)) / float(ITERATIONS), d );
        }
    }

    return res;
}

vec3 getNormal2(vec3 p) {
    vec2 e = vec2(1.0,-1.0)*0.5773;
    const float eps = 0.00025;
    return normalize( e.xyy*getScene( p + e.xyy*eps ).w + 
					  e.yyx*getScene( p + e.yyx*eps ).w + 
					  e.yxy*getScene( p + e.yxy*eps ).w + 
					  e.xxx*getScene( p + e.xxx*eps ).w );
}

vec3 getNormal(in vec3 pos) {
    vec3 eps = vec3(.0002,0.0,0.0);
    return normalize(vec3(
    getScene(pos+eps.xyy).w - getScene(pos-eps.xyy).w,
    getScene(pos+eps.yxy).w - getScene(pos-eps.yxy).w,
    getScene(pos+eps.yyx).w - getScene(pos-eps.yyx).w ));
}

vec3 pal( in float t, in vec3 a, in vec3 b, in vec3 c, in vec3 d )
{
    return a + b*cos( 6.28318*(c*t+d) );
}

struct Hit {
    float t;
    vec3 pos;
    vec3 normal;
    float ao;
    float m;
    float id;
};

void main() {
    vec2 st = coord(gl_FragCoord.xy);

    float T = u_time * 0.1 + 16.1;

    vec3 camera = vec3(sin(T) + T * 5.0, - 2.63, -T * 5.0);
    // rotateY(vec3(0.0, 3.0, -0.0), T);
    // camera = rotateX(camera, T);
    // camera = rotateZ(camera, T);

    vec3 ray = normalize(vec3(st, 0.5+0.2*sin(T)));
    ray = rotateY(ray, -sin(T));
    ray = rotateX(ray, T*1.0);


    Hit hit;
    hit.t = INF;
    hit.m = 1.0;
    hit.ao = 0.0;


    float t = 0.0;

    float scale = 0.4;
    vec3 p = camera;

    for (int i = 0; i < 1000; i++) {
        vec4 d = getScene(p * scale);

        if (d.w < 0.0001) {
            hit.t = t;
            hit.pos = p;
            hit.ao = d.g == 0.0 ? 1.0 : d.g;
            hit.m = d.b == 0.0 ? 1.0 : d.b;
            hit.normal =-getNormal2(p * scale);
            hit.id = d.r;
            break;
        }
        t += d.w;
        p += ray * d.w;
    }

    // sky based on ray dir
    vec3 fogColor = vec3(0.4745, 0.2353, 0.0941);
    vec3 up = vec3(0.0, -1.0, 0.0);
    float sky = dot(ray, up);
    fogColor = mix(fogColor, vec3(0.8627, 0.8118, 1.0), sky * 0.5 + 0.5);
    vec3 color = fogColor;

    if (hit.t != INF) {
        vec3 c = pal(fract(hit.id), 
        vec3(0.6314, 0.4392, 0.3725),vec3(0.3059, 0.1765, 0.0039), vec3(2.0, 1.0, 1.0), vec3(0.3412, 0.7333, 0.2392) );
        color = mix(vec3(0.0, 0.0, 0.0), c, hit.m) * hit.ao;

        // Lighting
        vec3 light = 0.1 + max(0.0, hit.normal.y) * vec3(1.0, 1.0, 1.0);

        color *= light;

        // Fog
        color = mix(color, fogColor, 1.0 - exp(-0.002 * hit.t * hit.t));
    }

    // Gamma correction
    color = pow(color, vec3(1.0 / 1.9));

    gl_FragColor = vec4(color, 1.0);
}