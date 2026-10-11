import simd

/// Mirrors `LivewallUniforms` in `ShaderSourceBuilder`; field order and types must match.
struct ShaderUniforms {
    var resolution: SIMD2<Float>
    var mouse: SIMD2<Float>
    var time: Float
}
