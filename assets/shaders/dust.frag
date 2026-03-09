#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 u_resolution;
uniform float u_progress;   // 0.0 to 1.0
uniform sampler2D u_image;

// We pass in 16 pre-computed random offsets from dart (-1.0 to 1.0 range)
// representing the X and Y displacement direction for each bucket.
uniform vec2 u_randoms[16];

out vec4 fragColor;

const int NUM_BUCKETS = 16;
const float PI = 3.14159265;

// The Snappable package uses a Gauss function to determine the probability
// that a given Y coordinate belongs to a given bucket.
// int _gauss(double center, double value) => (1000 * math.exp(-(math.pow((value - center), 2) / 0.14))).round();
float gauss(float center, float value) {
    return exp(-(pow(value - center, 2.0) / 0.14));
}

// Emulate Snappable's random weighted selection.
// Because GLSL doesn't have a built-in PRNG sequence state like dart:math, 
// we generate a stable pseudo-random value [0, 1) based on the exact continuous pixel coordinate.
float hash(vec2 p) {
    p = fract(p * vec2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

// Instead of computing forwards and dispersing, a shader must compute BACKWARDS.
// For the current pixel `pos`, we want to find out IF there is an original pixel `srcPos`
// that has moved *into* `pos` at this exact `u_progress`.
// Because we have exactly 16 discrete buckets that each move as a single rigid layer,
// we can simply check all 16 buckets.
void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    vec2 pos = FlutterFragCoord().xy; // (0,0) is top left

    // Pre-calculate the base displacement vector amplitude matching Snappable's default.
    // Snappable default offset is (64, -32), random disloc is (64, 32)
    vec2 baseSnapOffset = vec2(64.0, -32.0);
    vec2 baseRandomDisloc = vec2(64.0, 32.0);

    vec4 finalColor = vec4(0.0);
    bool foundPixel = false;
    vec2 sourcePosToSample = vec2(0.0);
    int assignedBucketIndex = -1;

    // Check every bucket sequentially. Is `pos` occupied by a pixel from bucket i?
    for (int i = 0; i < NUM_BUCKETS; i++) {
        float bucketIndexF = float(i);
        
        // Match Snappable's layer animation timing
        // _lastLayerAnimationStart = 1 - 0.6 = 0.4;
        float animationStartF = (bucketIndexF / float(NUM_BUCKETS)) * 0.4;
        float animationEndF = animationStartF + 0.6;
        
        // Interval mapping: similar to CurvedAnimation(curve: Interval(... easeOut))
        float bucketLocalProgress = 0.0;
        if (u_progress > animationStartF) {
            bucketLocalProgress = (u_progress - animationStartF) / (animationEndF - animationStartF);
        }
        bucketLocalProgress = clamp(bucketLocalProgress, 0.0, 1.0);
        
        // Apply an easeOut (approximate standard easeOut curve used in flutter: 1 - (1-t)^2)
        // You could also use sin(t * pi/2.0) but a quadratic or cubic is fine.
        float t = bucketLocalProgress;
        float easeOutT = sin(t * PI / 2.0);
        
        // Calculate the rigid displacement of this entire bucket at this point in time
        vec2 randomOffset = vec2(
            baseRandomDisloc.x * u_randoms[i].x,
            baseRandomDisloc.y * u_randoms[i].y
        );
        vec2 bucketDisplacement = (baseSnapOffset + randomOffset) * easeOutT;

        // Where was this pixel originally located before displacement?
        vec2 srcPos = pos - bucketDisplacement;
        
        // Out of bounds check on the source pixel
        if (srcPos.x < 0.0 || srcPos.x >= u_resolution.x || srcPos.y < 0.0 || srcPos.y >= u_resolution.y) {
            continue;
        }

        // Now, we must check: Did the pixel at `srcPos` ACTUALLY belong to bucket `i`?
        // We replicate Snappable's `_pickABucket` exactly here.
        float normY = srcPos.y / u_resolution.y;
        
        // Calculate the weights for all 16 buckets for this specific Y row.
        float weights[NUM_BUCKETS];
        float sumOfWeights = 0.0;
        for(int j=0; j < NUM_BUCKETS; j++) {
            float bucketCenter = float(j) / float(NUM_BUCKETS);
            // using the original formula:
            weights[j] = gauss(normY, bucketCenter);
            sumOfWeights += weights[j];
        }

        // We use our stable random hash based on the exact original pixel coordinate.
        // It's crucial this ignores time/displacement and only relies on the floor() of srcPos
        // so that the same pixel is always assigned to the same bucket forever.
        float rnd = hash(floor(srcPos)) * sumOfWeights;
        
        int pickedBucket = 0;
        for (int j = 0; j < NUM_BUCKETS; j++) {
            if (rnd < weights[j]) {
                pickedBucket = j;
                break;
            }
            rnd -= weights[j];
        }

        // Did it belong to this bucket?
        if (pickedBucket == i) {
            // YES! We have found the *single valid* pixel that occupies `pos` right now.
            // There are no overlaps because the buckets are mutually exclusive partitions of the image.
            sourcePosToSample = srcPos;
            assignedBucketIndex = i;
            bucketLocalProgress = t; // save it to calculate opacity later
            foundPixel = true;
            break;
        }
    }

    if (!foundPixel) {
        fragColor = vec4(0.0);
        return;
    }

    // Normalise
    vec2 sampleUv = sourcePosToSample / u_resolution;
    vec4 color = texture(u_image, sampleUv);

    // Fade it out based on the local progress of the bucket, matching snappable's Opacity:
    // math.cos(animation.value * math.pi / 2)
    float baseProgress = u_progress;
    float animationStartF = (float(assignedBucketIndex) / float(NUM_BUCKETS)) * 0.4;
    float t = clamp((u_progress - animationStartF) / 0.6, 0.0, 1.0);
    // math.cos gets applied to the CurvedAnimation value
    float easeOutT = sin(t * PI / 2.0); 
    float opacity = cos(easeOutT * PI / 2.0);
    
    // The alpha output must be premultiplied
    fragColor = color * opacity;
}
