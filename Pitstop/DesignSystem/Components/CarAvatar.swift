import SwiftUI

/// What the avatar draws: the car's chosen body and its photo files, as the car board last read them.
struct CarAvatarSource: Hashable, Sendable {
    let body: CarBody
    let photo: CarPhotoFiles?
}

extension EnvironmentValues {
    /// Set once by the root from the car board state; `nil` outside the root (previews), where no avatar is drawn.
    @Entry var carAvatar: CarAvatarSource?
}

/// The car as a small round avatar, where seeing it helps (ADR 0040 "One component", REQ-BOARD-034). It keeps its
/// size at every text size and is decorative: the screen around it already names the car.
struct CarAvatar: View {
    enum Size: Sendable {
        /// Before the eyebrow of a detail screen header.
        case header
        /// In the Pit sheet's saved state and question card.
        case pit

        var diameter: CGFloat {
            switch self {
            case .header: 28
            case .pit: 44
            }
        }

        /// The width a fitted car takes inside the circle (mockup `.avatar svg`: 24 of 28, 36 of 44).
        var carWidth: CGFloat {
            switch self {
            case .header: 24
            case .pit: 36
            }
        }
    }

    /// The stage's strong tint (mockup `--p-tint2`), so the small car stands on the same ground as the hero.
    nonisolated static let backgroundColor = PitColor.surfaceTintStrong

    let source: CarAvatarSource
    let size: Size

    @State private var loaded: LoadedCarPhoto?

    var body: some View {
        // The same resolution as `CarVisual`; only the frame the picture is drawn in differs.
        CarAvatarPicture(
            picture: LoadedCarPhoto.picture(body: source.body, photo: source.photo, loaded: loaded),
            size: size
        )
        .task(id: source.photo) {
            guard let photo = source.photo, loaded?.photo != photo else { return }
            loaded = await LoadedCarPhoto.read(body: source.body, photo: photo)
        }
        .accessibilityHidden(true)
    }
}

/// Draws one resolved picture in the round avatar.
struct CarAvatarPicture: View {
    let picture: CarPicture?
    let size: CarAvatar.Size

    var body: some View {
        ZStack {
            CarAvatar.backgroundColor
            content
        }
        .frame(width: size.diameter, height: size.diameter)
        .clipShape(.circle)
    }

    @ViewBuilder
    private var content: some View {
        switch picture {
        case let .lifted(image):
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .frame(width: size.carWidth, height: size.carWidth / 2)
        case let .whole(image):
            // "Cropped to a small round avatar" (mockup, Car profile): the whole photo fills the circle.
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .frame(width: size.diameter, height: size.diameter)
        case let .placeholder(body):
            Image(CarVisual.placeholderAssetName(body))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(CarVisual.placeholderColor)
                .frame(width: size.carWidth, height: size.carWidth / 2)
        case nil:
            EmptyView()
        }
    }
}

#if DEBUG
    /// Fictional stand-ins for an owner's photo: blocks of colour, never a real car or place.
    private enum CarAvatarPreviewPictures {
        static func block(width: Int, height: Int, opaque: Bool) -> CGImage? {
            guard
                let context = CGContext(
                    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
                )
            else { return nil }
            if opaque {
                context.setFillColor(CGColor(red: 0.55, green: 0.66, blue: 0.52, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            context.setFillColor(CGColor(red: 0.62, green: 0.18, blue: 0.16, alpha: 1))
            context.fill(CGRect(x: width / 10, y: height / 5, width: width * 8 / 10, height: height / 2))
            return context.makeImage()
        }
    }

    #Preview("Car avatar") {
        PreviewMatrix {
            ForEach([CarAvatar.Size.header, .pit], id: \.diameter) { size in
                HStack(spacing: 12) {
                    ForEach(CarBody.allCases, id: \.self) { body in
                        CarAvatar(source: CarAvatarSource(body: body, photo: nil), size: size)
                    }
                    CarAvatarPicture(
                        picture: CarAvatarPreviewPictures.block(width: 200, height: 100, opaque: false)
                            .map(CarPicture.lifted),
                        size: size
                    )
                    CarAvatarPicture(
                        picture: CarAvatarPreviewPictures.block(width: 160, height: 120, opaque: true)
                            .map(CarPicture.whole),
                        size: size
                    )
                    Text(verbatim: "Kestrel")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(PitColor.contentSecondary)
                }
            }
        }
    }
#endif
