import SwiftUI

/// Shared header grammar: eyebrow / context, then a large title.
struct ScreenHeader: View {
    let eyebrow: String
    let title: String
    /// The car's avatar before the eyebrow, on detail screens only; Car Board's hero already shows the car
    /// (screen-grammar.md, REQ-BOARD-034).
    var avatar: CarAvatarSource?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            eyebrowLine
            Text(title)
                .font(.largeTitle.bold())
                .foregroundStyle(PitColor.contentPrimary)
                // A user-entered car name must stay readable at accessibility sizes.
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 4 : 2)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    @ViewBuilder
    private var eyebrowLine: some View {
        if let avatar {
            // The avatar keeps 28 pt; at accessibility sizes the eyebrow wraps under it rather than being squeezed
            // beside it (mockup, Car profile "Dynamic Type").
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(spacing: 8))
            layout {
                CarAvatar(source: avatar, size: .header)
                eyebrowText
            }
        } else {
            eyebrowText
        }
    }

    private var eyebrowText: some View {
        Text(eyebrow)
            .font(.footnote.weight(.semibold))
            .textCase(.uppercase)
            .kerning(0.8)
            .foregroundStyle(PitColor.contentSecondary)
    }
}

#if DEBUG
    #Preview("Screen header") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: "Kestrel", title: "Service", avatar: CarAvatarSource(body: .suv, photo: nil))
                ScreenHeader(eyebrow: "Kestrel", title: "Notes", avatar: CarAvatarSource(body: .sedan, photo: nil))
                // Car Board's own header: no avatar, the hero shows the car.
                ScreenHeader(eyebrow: "My car", title: "Kestrel")
            }
        }
    }
#endif
