import Foundation

/// Wraps a user shader in the boilerplate needed to draw it full-screen.
///
/// Shader contract — the user file must define:
///
///     float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse)
///
/// `fragCoord` and `mouse` are in pixels with the origin at the bottom-left (Shadertoy convention),
/// `time` is in seconds and stops advancing while the wallpaper is paused.
enum ShaderSourceBuilder {
    static let vertexFunction = "livewall_vertex"
    static let fragmentFunction = "livewall_fragment"

    static func build(userSource: String) -> String {
        """
        #include <metal_stdlib>
        using namespace metal;

        struct LivewallUniforms {
            float2 resolution;
            float2 mouse;
            float time;
        };

        struct LivewallVertexOut {
            float4 position [[position]];
        };

        vertex LivewallVertexOut \(vertexFunction)(uint vid [[vertex_id]]) {
            float2 p = float2((vid << 1) & 2, vid & 2);
            LivewallVertexOut out;
            out.position = float4(p * 2.0 - 1.0, 0.0, 1.0);
            return out;
        }

        #line 1 "wallpaper.metal"
        \(userSource)

        fragment float4 \(fragmentFunction)(LivewallVertexOut in [[stage_in]],
                                            constant LivewallUniforms& u [[buffer(0)]]) {
            float2 fragCoord = float2(in.position.x, u.resolution.y - in.position.y);
            return wallpaper(fragCoord, u.resolution, u.time, u.mouse);
        }
        """
    }
}
