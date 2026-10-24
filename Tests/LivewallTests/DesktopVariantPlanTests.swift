import CoreGraphics
import Testing
@testable import Livewall

@Suite struct DesktopVariantPlanTests {
    private let retina13 = CGSize(width: 2880, height: 1800)

    @Test func fourK60MakesDisplaySizedCopiesAt60And30() {
        let plan = DesktopVariantPlan(sourceSize: CGSize(width: 3840, height: 2160), sourceFrameRate: 60, display: retina13)
        #expect(plan.variants == [
            .init(quality: .optimized, size: CGSize(width: 3200, height: 1800), frameRate: 60),
            .init(quality: .batterySaver, size: CGSize(width: 3200, height: 1800), frameRate: 30),
        ])
    }

    @Test func screenSized30fpsVideoNeedsNoCopy() {
        let plan = DesktopVariantPlan(sourceSize: CGSize(width: 2880, height: 1800), sourceFrameRate: 29.97, display: retina13)
        #expect(plan.variants.isEmpty)
    }

    @Test func smallVideoIsNeverUpscaledButStillGetsA30fpsCopy() {
        let plan = DesktopVariantPlan(sourceSize: CGSize(width: 1920, height: 1080), sourceFrameRate: 60, display: retina13)
        #expect(plan.variants == [.init(quality: .batterySaver, size: CGSize(width: 1920, height: 1080), frameRate: 30)])
    }
}
