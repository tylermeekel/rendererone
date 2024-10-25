#include <metal_stdlib>
using namespace metal;

// Renderer-wide Data
struct Uniforms {
    float4x4 projection;
    float4x4 view;
    float4x4 model;
    float3 camera_pos;
};

// Pass-specific Data, this is the only one for now
// since we only have one render pass!
struct Params {
    float time;
    int num_sines;
};

// Structs for Organization
struct SineWave {
    float amplitude;
    float wavelength;
    float speed;
    packed_float2 direction;
};

struct VertexOut {
    float4 position [[position]];
    float3 normal;
    float4 world_pos;
    float3 camera_pos;
};

vertex VertexOut vertex_main(uint vertex_id [[vertex_id]],
                    constant packed_float3 *positions [[buffer(0)]],
                    constant Uniforms &uniforms [[buffer(1)]],
                    constant Params &params [[buffer(2)]],
                    constant SineWave *sinewaves [[buffer(11)]]
)
{
    float eulers = 2.71828182845904523536;
    VertexOut o;
    packed_float3 pos = positions[vertex_id];

    float tangent = 0;
    float bitangent = 0;
    float prevtangent = 0;
    float prevbitangent = 0;

    float amplitude_mult = 1;
    float amplitude_ramp = 0.93;
    float frequency_mult = 1;
    float frequency_ramp = 1.04;

    for (int i = 0; i < params.num_sines; i++) {
        SineWave sw = sinewaves[i];

        float amplitude = sw.amplitude * amplitude_mult;
        float wavelength = sw.wavelength;
        float frequency = (2.0 / wavelength) * frequency_mult; // don't touch
        float speed = sw.speed;
        float phase = speed * frequency; // don't touch

        float2 direction = normalize(float2(sw.direction));

        pos.y += amplitude * pow(eulers, sin(dot(direction, pos.xz + float2(prevtangent, prevbitangent)) * frequency + params.time * phase));
        prevtangent = frequency * amplitude * direction.x * 
            pow(eulers, amplitude * sin(dot(direction, pos.xz + float2(prevtangent, prevbitangent)) * frequency + params.time * phase) - 1) *
            cos(dot(direction, pos.xz) * frequency + params.time * phase);
        prevbitangent = frequency * amplitude * direction.y * 
            pow(eulers, amplitude * sin(dot(direction, pos.xz + float2(prevtangent, prevbitangent)) * frequency + params.time * phase) - 1) *
            cos(dot(direction, pos.xz) * frequency + params.time * phase);

        tangent += prevtangent;
        bitangent += prevbitangent;

        amplitude_mult *= amplitude_ramp;
        frequency_mult *= frequency_ramp;
    }

    float3 normal = float3(-tangent, 1, -bitangent);

    o.normal = normal;
    o.world_pos = float4(pos, 1);
    o.world_pos *= uniforms.model;
    o.position = uniforms.projection * uniforms.view * uniforms.model * float4(pos, 1.0);
    
    // forward the camera position to the
    // fragment shader
    o.camera_pos = uniforms.camera_pos;

    return o;
}

float4 fog(float4 position, float4 color) {
    float distance = position.z / position.w;
    float density = 0.008;
    float fog = 1.0 - clamp(pow(exp2(-density * distance), 2), 0.0, 1.0);
    float4 fogColor = float4(1, 0.5, 0.2, 1.0);
    color = mix(color, fogColor, fog);
    return color;
};

float4 fragment fragment_main(
    VertexOut in [[stage_in]],
    depth2d<float> depth_texture [[texture(21)]]) {
    constexpr sampler s(filter::linear, address::clamp_to_edge);

    float depth_sample = depth_texture.sample(s, in.position.xy);

    float3 water_color = float3(17/255.0, 41/255.0, 85/255.0);
    //float3 light_color = float3(235.0/255.0, 235.0/255.0, 178.0/228.0);
    float3 light_color = float3(1, 0.5, 0.2);
    
    float3 light_pos = float3(0, 20, -60);
    float3 light_direction = normalize(light_pos - in.world_pos.xyz);

    float3 normal = normalize(in.normal);

    float specular_strength = 1;
    float3 view_dir = normalize(in.camera_pos - in.world_pos.xyz);
    float3 reflect_dir = reflect(-light_direction, normal);
    float3 spec = pow(max(dot(view_dir, reflect_dir), 0.0), 2048); 
    
    float3 ambient = 0.25;
    float3 diffuse = 1 * saturate(dot(normal, light_direction)) * light_color;
    float3 specular = specular_strength * spec * light_color;

    float3 result = (specular + ambient + diffuse) * water_color;
    float4 final = fog(in.position, float4(result, 1.0));
    return final;
}
