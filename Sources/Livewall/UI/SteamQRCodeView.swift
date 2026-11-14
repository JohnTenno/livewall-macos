import SwiftUI

/// Draws a Steam login QR code black on white with a quiet border, so phone cameras read it in light or dark mode.
struct SteamQRCodeView: View {
    let code: SteamQRCode

    var body: some View {
        Canvas { context, size in
            let count = CGFloat(code.modules.count)
            let module = size.width / count
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for (y, row) in code.modules.enumerated() {
                for (x, dark) in row.enumerated() where dark {
                    context.fill(Path(CGRect(x: CGFloat(x) * module, y: CGFloat(y) * module, width: module, height: module)), with: .color(.black))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("Steam sign-in QR code")
    }
}
