import Foundation

/// Shaders shipped with the app. Each implements the Livewall shader contract (see `ShaderSourceBuilder`).
enum BuiltInShaders {
    private struct Entry {
        let id: String
        let key: String
        let name: String
        let source: String
    }

    private static let entries: [Entry] = [
        Entry(id: "6F1D2C1A-4B7E-4C11-9C1E-0A0000000001", key: "aurora", name: "Aurora", source: aurora),
        Entry(id: "6F1D2C1A-4B7E-4C11-9C1E-0A0000000002", key: "plasma", name: "Plasma", source: plasma),
        Entry(id: "6F1D2C1A-4B7E-4C11-9C1E-0A0000000003", key: "ripples", name: "Ondas", source: ripples),
    ]

    static let wallpapers: [Wallpaper] = entries.map {
        Wallpaper(id: UUID(uuidString: $0.id)!, name: $0.name, kind: .shader, source: .builtInShader($0.key))
    }

    static func source(forKey key: String) -> String? {
        entries.first { $0.key == key }?.source
    }

    private static let aurora = """
    float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse) {
        float2 uv = fragCoord / resolution;
        float3 col = mix(float3(0.01, 0.02, 0.06), float3(0.02, 0.05, 0.12), uv.y);
        float drift = (mouse.x / resolution.x - 0.5) * 0.4;
        for (int i = 0; i < 4; i++) {
            float fi = float(i);
            float wave = 0.55 + 0.08 * fi
                + 0.06 * sin(uv.x * (3.0 + fi) + time * (0.15 + 0.05 * fi) + drift)
                + 0.03 * sin(uv.x * 11.0 - time * 0.4 + fi);
            float d = (uv.y - wave) * (14.0 - fi * 2.0);
            float band = exp(-d * d);
            float3 tint = 0.5 + 0.5 * cos(6.2831 * (float3(0.3, 0.5, 0.7) + fi * 0.12 + uv.x * 0.2));
            col += band * tint * 0.35;
        }
        return float4(col, 1.0);
    }
    """

    private static let plasma = """
    float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse) {
        float2 uv = fragCoord / resolution.y;
        float2 m = mouse / resolution.y;
        float t = time * 0.3;
        float v = sin(uv.x * 6.0 + t)
            + sin(uv.y * 5.0 - t * 1.3)
            + sin((uv.x + uv.y) * 4.0 + t * 0.7)
            + sin(length(uv - m) * 8.0 - t * 2.0);
        float3 col = 0.5 + 0.5 * cos(v + float3(0.0, 2.1, 4.2));
        return float4(col * 0.8, 1.0);
    }
    """

    private static let ripples = """
    float4 wallpaper(float2 fragCoord, float2 resolution, float time, float2 mouse) {
        float2 uv = (fragCoord - 0.5 * resolution) / resolution.y;
        float2 m = (mouse - 0.5 * resolution) / resolution.y;
        float d = length(uv - m);
        float rings = sin(d * 40.0 - time * 3.0) * exp(-d * 3.0);
        float2 p = uv + normalize(uv - m + 1e-4) * rings * 0.01;
        float2 g = abs(fract(p * 10.0) - 0.5);
        float line = smoothstep(0.03, 0.0, 0.5 - max(g.x, g.y));
        float3 col = float3(0.02, 0.03, 0.05)
            + line * float3(0.1, 0.5, 0.9) * (0.3 + 0.7 * exp(-d * 2.0))
            + rings * float3(0.05, 0.1, 0.2);
        return float4(max(col, 0.0), 1.0);
    }
    """
}
