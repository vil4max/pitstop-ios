import SwiftUI

/// What the car is drawn from, in the fallback order of ADR 0040 "One component".
enum CarPicture: Sendable {
    /// The subject cut out of the owner's photo, standing on the stage.
    case lifted(CGImage)
    /// The owner's photo as a whole, under the stage mask, when the subject could not be lifted (REQ-BOARD-031).
    case whole(CGImage)
    /// The neutral side view of the owner's chosen body, facing right (REQ-DESIGN-005).
    case placeholder(CarBody)

    /// The lifted cut-out, else the whole original, else the body's placeholder. A file that is missing or does
    /// not decode falls through to the next, so a broken photo shows the car and never an error (REQ-BOARD-031).
    static func resolve(body: CarBody, photo: CarPhotoFiles?, decode: (URL) -> CGImage?) -> CarPicture {
        if let lifted = photo?.lifted, let image = decode(lifted) {
            return .lifted(image)
        }
        if let original = photo?.original, let image = decode(original) {
            return .whole(image)
        }
        return .placeholder(body)
    }
}

extension CarPicture: Equatable {
    static func == (lhs: CarPicture, rhs: CarPicture) -> Bool {
        switch (lhs, rhs) {
        case let (.lifted(left), .lifted(right)), let (.whole(left), .whole(right)): left === right
        case let (.placeholder(left), .placeholder(right)): left == right
        default: false
        }
    }
}

/// How a view that draws the car reads the photo's files (`CarPhotoDecoder` is the live one). Views reach it
/// through the environment, so a test reads through a decoder of its own rather than the one every view shares.
protocol CarPhotoDecoding: Sendable {
    /// The picture from files already decoded, or `nil` while a file it needs has not been read yet.
    func cachedPicture(body: CarBody, photo: CarPhotoFiles) -> CarPicture?
    /// Reads the files the picture needs, off the main actor.
    func load(body: CarBody, photo: CarPhotoFiles) async -> CarPicture
}

extension EnvironmentValues {
    @Entry var carPhotoDecoder: any CarPhotoDecoding = CarPhotoDecoder.shared
}

/// The car wherever it appears: the stage, the Car Board tiles and the Road lane (ADR 0040 "One component").
/// Every picture is fitted into one frame and stands on its bottom edge, so wheels rest on a road line drawn
/// level with the frame's bottom.
struct CarVisual: View {
    /// Width over height of the frame: the SUV placeholder's, the taller of the two bodies.
    nonisolated static let aspectRatio: CGFloat = 960.0 / 334.0
    /// The placeholder's only colour; the catalog images are templates (REQ-DESIGN-004).
    nonisolated static let placeholderColor = PitColor.contentSecondary

    nonisolated static func placeholderAssetName(_ body: CarBody) -> String {
        switch body {
        case .suv: "CarPlaceholderSUV"
        case .sedan: "CarPlaceholderSedan"
        }
    }

    let carBody: CarBody
    let photo: CarPhotoFiles?
    /// Spoken for the car when given; without one the car is decorative (REQ-BOARD-024).
    var label: Text?

    @Environment(\.carPhotoDecoder) private var decoder
    @State private var loaded: LoadedCarPhoto?

    init(body: CarBody, photo: CarPhotoFiles?, label: Text? = nil) {
        carBody = body
        self.photo = photo
        self.label = label
    }

    var body: some View {
        CarPictureView(
            picture: LoadedCarPhoto.picture(body: carBody, photo: photo, loaded: loaded, decoder: decoder)
        )
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .task(id: photo) {
            guard let photo, loaded?.photo != photo else { return }
            loaded = await LoadedCarPhoto.read(body: carBody, photo: photo, decoder: decoder)
        }
        .modifier(CarVisualAccessibility(label: label))
    }
}

/// The picture rule every surface that draws the car shares (`CarVisual`, `CarAvatar`): the photo files a view
/// last read, and what to draw from them.
struct LoadedCarPhoto: Sendable {
    let photo: CarPhotoFiles
    let picture: CarPicture

    static func read(body: CarBody, photo: CarPhotoFiles, decoder: any CarPhotoDecoding) async -> LoadedCarPhoto {
        await LoadedCarPhoto(photo: photo, picture: decoder.load(body: body, photo: photo))
    }

    /// `nil` only while a photo's files are being read: the frame stays empty rather than showing, for a
    /// moment, a body that is not the owner's car.
    static func picture(
        body: CarBody,
        photo: CarPhotoFiles?,
        loaded: LoadedCarPhoto?,
        decoder: any CarPhotoDecoding
    ) -> CarPicture? {
        guard let photo else { return .placeholder(body) }
        if let loaded, loaded.photo == photo {
            // A photo that fell back to the placeholder follows the body chosen since it was read.
            if case .placeholder = loaded.picture {
                return .placeholder(body)
            }
            return loaded.picture
        }
        // Another surface may have read these files already: the tiles and the lane draw them at once.
        return decoder.cachedPicture(body: body, photo: photo)
    }
}

/// Draws one resolved picture, bottom-aligned in the space it is given.
struct CarPictureView: View {
    let picture: CarPicture?

    var body: some View {
        GeometryReader { proxy in
            content(in: proxy.size)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .bottom)
        }
    }

    @ViewBuilder
    private func content(in size: CGSize) -> some View {
        switch picture {
        case let .lifted(image):
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
        case let .whole(image):
            // The stage mask: the photo's edges fade into the stage, so a rectangle of scenery does not read
            // as a card laid on it.
            let feather = min(size.width, size.height) * 0.08
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFit()
                .mask {
                    RoundedRectangle(cornerRadius: feather * 2, style: .continuous)
                        .padding(feather)
                        .blur(radius: feather)
                }
        case let .placeholder(body):
            Image(CarVisual.placeholderAssetName(body))
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
                .foregroundStyle(CarVisual.placeholderColor)
        case nil:
            Color.clear
        }
    }
}

private struct CarVisualAccessibility: ViewModifier {
    let label: Text?

    func body(content: Content) -> some View {
        if let label {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(label)
                .accessibilityAddTraits(.isImage)
        } else {
            content.accessibilityHidden(true)
        }
    }
}

#if DEBUG
    /// Fictional stand-ins for an owner's photo: blocks of colour, never a real car or place.
    private enum CarVisualPreviewPictures {
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
            context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
            for center in [width / 4, width * 3 / 4] {
                context.fillEllipse(
                    in: CGRect(
                        x: center - height / 5,
                        y: 0,
                        width: height * 2 / 5,
                        height: height * 2 / 5
                    ))
            }
            return context.makeImage()
        }
    }

    #Preview("Car visual") {
        PreviewMatrix {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(CarBody.allCases, id: \.self) { body in
                    StageSurface {
                        CarVisual(body: body, photo: nil)
                            .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
                    }
                }
                StageSurface {
                    CarPictureView(
                        picture: CarVisualPreviewPictures.block(width: 600, height: 200, opaque: false)
                            .map(CarPicture.lifted)
                    )
                    .aspectRatio(CarVisual.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
                }
                StageSurface {
                    CarPictureView(
                        picture: CarVisualPreviewPictures.block(width: 400, height: 300, opaque: true)
                            .map(CarPicture.whole)
                    )
                    .aspectRatio(CarVisual.aspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
                }
            }
        }
    }
#endif
