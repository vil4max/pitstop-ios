import SwiftUI

/// Neutral fallback car visual. A model-specific image must never stand in for a car the
/// user has not identified (product-design.md, "Car image").
struct AbstractCarShape: Shape {
    func path(in rect: CGRect) -> Path {
        func point(_ unitX: CGFloat, _ unitY: CGFloat) -> CGPoint {
            CGPoint(x: rect.minX + unitX * rect.width, y: rect.minY + unitY * rect.height)
        }
        var path = Path()
        path.move(to: point(0.03, 0.76))
        path.addLine(to: point(0.04, 0.60))
        path.addCurve(to: point(0.30, 0.44), control1: point(0.08, 0.52), control2: point(0.20, 0.47))
        path.addCurve(to: point(0.45, 0.20), control1: point(0.35, 0.34), control2: point(0.39, 0.22))
        path.addLine(to: point(0.63, 0.20))
        path.addCurve(to: point(0.84, 0.45), control1: point(0.72, 0.22), control2: point(0.78, 0.36))
        path.addCurve(to: point(0.97, 0.60), control1: point(0.91, 0.47), control2: point(0.96, 0.52))
        path.addLine(to: point(0.97, 0.76))
        path.closeSubpath()
        return path
    }
}

struct AbstractCarView: View {
    /// Width over height. The wheels sit at the bottom of the frame, so a lane can stand them on its road line.
    nonisolated static let aspectRatio: CGFloat = 2.6

    var body: some View {
        GeometryReader { proxy in
            let wheel = proxy.size.width * 0.17
            ZStack {
                AbstractCarShape()
                    .fill(LinearGradient(
                        colors: [PitColor.accentPrimary.opacity(0.55), PitColor.accentPrimary.opacity(0.25)],
                        startPoint: .top,
                        endPoint: .bottom
                    ))
                ForEach([0.24, 0.77], id: \.self) { wheelCenter in
                    Circle()
                        .fill(PitColor.surfacePrimary)
                        .overlay(Circle().strokeBorder(PitColor.contentSecondary.opacity(0.6), lineWidth: wheel * 0.16))
                        .frame(width: wheel, height: wheel)
                        .position(x: proxy.size.width * wheelCenter, y: proxy.size.height * 0.76)
                }
            }
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        // Decorative: the name next to it already identifies the car (REQ-BOARD-024).
        .accessibilityHidden(true)
    }
}
