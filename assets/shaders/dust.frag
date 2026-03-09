#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;     // Size of the entire CustomPaint expanded area
uniform vec2 u_image_size;     // Size of the original chat bubble
uniform vec2 u_image_offset;  // (dx, dy) padding of the image inside the expanded area
uniform float u_progress;      // 0.0 to 1.0
uniform sampler2D u_image;

// 16 pre-computed random offsets
uniform vec2 u_randoms[16];

out vec4 fragColor;

const int NUM_BUCKETS = 16;
const float PI = 3.14159265;

float gauss(float center, float value) {
    return exp(-(pow(value - center, 2.0) / 0.14));
}

float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

void main() {
    // Current pixel in the expanded canvas space
    vec2 pos = FlutterFragCoord().xy; 

    // Base displacement parameters
    vec2 baseSnapOffset = vec2(64.0, -32.0);
    vec2 baseRandomDisloc = vec2(64.0, 32.0);

    vec4 finalColor = vec4(0.0);
    bool foundPixel = false;
    vec2 sourcePosToSample = vec2(0.0);
    int assignedBucketIndex = -1;

    // Check all buckets
    for (int i = 0; i < NUM_BUCKETS; i++) {
        float bucketIndexF = float(i);
        float animationStartF = (bucketIndexF / float(NUM_BUCKETS)) * 0.4;
        float animationEndF = animationStartF + 0.6;
        
        float bucketLocalProgress = 0.0;
        if (u_progress > animationStartF) {
            bucketLocalProgress = (u_progress - animationStartF) / (animationEndF - animationStartF);
        }
        bucketLocalProgress = clamp(bucketLocalProgress, 0.0, 1.0);
        
        float t = bucketLocalProgress;
        float easeOutT = sin(t * PI / 2.0);
        
        vec2 randomOffset = vec2(
            baseRandomDisloc.x * u_randoms[i].x,
            baseRandomDisloc.y * u_randoms[i].y
        );
        vec2 bucketDisplacement = (baseSnapOffset + randomOffset) * easeOutT;

        // Where was this pixel originally? (Still in expanded canvas space)
        vec2 srcPos = pos - bucketDisplacement;
        
        // Translate to the original image's local space
        vec2 imgPos = srcPos - u_image_offset;

        // Is this source pixel inside the original image bounds?
        if (imgPos.x < 0.0 || imgPos.x >= u_image_size.x || imgPos.y < 0.0 || imgPos.y >= u_image_size.y) {
            continue;
        }

        // Did the pixel at `imgPos` ACTUALLY belong to bucket `i`?
        float normY = imgPos.y / u_image_size.y;
        
        float weights[NUM_BUCKETS];
        float sumOfWeights = 0.0;
        for(int j=0; j < NUM_BUCKETS; j++) {
            float bucketCenter = float(j) / float(NUM_BUCKETS);
            weights[j] = gauss(normY, bucketCenter);
            sumOfWeights += weights[j];
        }

        // Hash based on the local image coordinate so particles never shift identity
        float rnd = hash(floor(imgPos)) * sumOfWeights;
        
        int pickedBucket = 0;
        for (int j = 0; j < NUM_BUCKETS; j++) {
            if (rnd < weights[j]) {
                pickedBucket = j;
                break;
            }
            rnd -= weights[j];
        }

        if (pickedBucket == i) {
            sourcePosToSample = imgPos; // Save the source local image position
            assignedBucketIndex = i;
            foundPixel = true;
            break;
        }
    }

    if (!foundPixel) {
        fragColor = vec4(0.0);
        return;
    }

    // Normalise to 0-1 based on the actual image size
    vec2 sampleUv = sourcePosToSample / u_image_size;
    vec4 color = texture(u_image, sampleUv);

    // Fade it out
    float animationStartF = (float(assignedBucketIndex) / float(NUM_BUCKETS)) * 0.4;
    float t = clamp((u_progress - animationStartF) / 0.6, 0.0, 1.0);
    float easeOutT = sin(t * PI / 2.0); 
    float opacity = cos(easeOutT * PI / 2.0);
    
    fragColor = color * opacity;
}
