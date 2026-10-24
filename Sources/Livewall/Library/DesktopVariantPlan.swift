import CoreGraphics

/// Decides which desktop copies of a video are worth encoding for the current displays.
struct DesktopVariantPlan: Equatable {
    struct Variant: Equatable {
        let quality: DesktopVideoQuality
        let size: CGSize
        let frameRate: Int
    }

    let variants: [Variant]

    /// `display` is the largest backing size in pixels. Videos fill the screen, so the copy keeps the
    /// video's aspect ratio and covers the display; it is never upscaled.
    init(sourceSize: CGSize, sourceFrameRate: Double, display: CGSize) {
        let scale = min(1, max(display.width / sourceSize.width, display.height / sourceSize.height))
        let even = { (value: CGFloat) in CGFloat(Int((value / 2).rounded()) * 2) }
        let size = CGSize(width: even(sourceSize.width * scale), height: even(sourceSize.height * scale))
        let fps = max(1, Int(sourceFrameRate.rounded()))
        // Below ~5% smaller the copy only costs disk space.
        let isSmaller = scale < 0.95
        var variants: [Variant] = []
        if isSmaller { variants.append(Variant(quality: .optimized, size: size, frameRate: fps)) }
        if fps > 30 { variants.append(Variant(quality: .batterySaver, size: size, frameRate: min(fps, 30))) }
        self.variants = variants
    }
}
