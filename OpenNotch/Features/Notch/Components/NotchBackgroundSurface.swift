import SwiftUI

struct NotchBackgroundSurface: View {
    let topCornerRadius: CGFloat
    let bottomCornerRadius: CGFloat

    var body: some View {
        baseSurface(shape: shape)
            .contentShape(shape)
    }

    private var shape: NotchShape {
        NotchShape(topCornerRadius: topCornerRadius, bottomCornerRadius: bottomCornerRadius)
    }

    private func baseSurface(shape: NotchShape) -> some View {
        shape.fill(.black)
    }
}
