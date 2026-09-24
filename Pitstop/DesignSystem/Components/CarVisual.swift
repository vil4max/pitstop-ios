import ImageIO
import SwiftUI
import Synchronization

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

/// Reads the car photo's files at display size. Files never change under one name (a new photo gets a new id,
/// so new names), which makes the URL a safe cache key; the stage, the tiles and the lane share one decode.
enum CarPhotoDecoder {
    /// Enough for the widest use, the stage at 3x; the stored original can be up to 2048 px.
    static let maxPixelSize = 1200
    /// One car has at most a few files alive at once; the cache starts over rather than tracking age.
    private static let cacheLimit = 8
    /// `nil` inside records a file that was tried and did not decode, so a broken file is not read again.
    private static let cache = Mutex<[URL: CGImage?]>([:])

    /// The image at `url`, bounded to `maxPixelSize` on its long side and never enlarged; `nil` when the file is
    /// missing or is not an image.
    static func decode(_ url: URL) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), CGImageSourceGetCount(source) > 0 else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        guard max(width, height) > maxPixelSize else {
            return CGImageSourceCreateImageAtIndex(
                source,
                0,
                [kCGImageSourceShouldCacheImmediately: true] as CFDictionary
            )
        }
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }

    /// The picture from files already decoded, or `nil` while a file it needs has not been read yet.
    static func cachedPicture(body: CarBody, photo: CarPhotoFiles) -> CarPicture? {
        let entries = cache.withLock { $0 }
        var isComplete = true
        let picture = CarPicture.resolve(body: body, photo: photo) { url in
            guard let entry = entries[url] else {
                isComplete = false
                return nil
            }
            return entry
        }
        return isComplete ? picture : nil
    }

    /// Reads the files the picture needs off the main actor, through the shared cache.
    @concurrent
    static func load(body: CarBody, photo: CarPhotoFiles) async -> CarPicture {
        CarPicture.resolve(body: body, photo: photo) { url in
            if let entry = cache.withLock({ $0[url] }) {
                return entry
            }
            let image = decode(url)
            cache.withLock { entries in
                if entries.count >= cacheLimit {
                    entries.removeAll()
                }
                entries[url] = .some(image)
            }
            return image
        }
    }
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

    @State private var loaded: Loaded?

    init(body: CarBody, photo: CarPhotoFiles?, label: Text? = nil) {
        carBody = body
        self.photo = photo
        self.label = label
    }

    var body: some View {
        CarPictureView(picture: picture)
            .aspectRatio(Self.aspectRatio, contentMode: .fit)
            .task(id: photo) {
                guard let photo, loaded?.photo != photo else { return }
                let picture = await CarPhotoDecoder.load(body: carBody, photo: photo)
                loaded = Loaded(photo: photo, picture: picture)
            }
            .modifier(CarVisualAccessibility(label: label))
    }

    /// `nil` only while a photo's files are being read: the frame stays empty rather than showing, for a
    /// moment, a body that is not the owner's car.
    private var picture: CarPicture? {
        guard let photo else { return .placeholder(carBody) }
        if let loaded, loaded.photo == photo {
            // A photo that fell back to the placeholder follows the body chosen since it was read.
            if case .placeholder = loaded.picture {
                return .placeholder(carBody)
            }
            return loaded.picture
        }
        // Another surface may have read these files already: the tiles and the lane draw them at once.
        return CarPhotoDecoder.cachedPicture(body: carBody, photo: photo)
    }

    private struct Loaded {
        let photo: CarPhotoFiles
        let picture: CarPicture
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
            guard let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return nil }
            if opaque {
                context.setFillColor(CGColor(red: 0.55, green: 0.66, blue: 0.52, alpha: 1))
                context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            }
            context.setFillColor(CGColor(red: 0.62, green: 0.18, blue: 0.16, alpha: 1))
            context.fill(CGRect(x: width / 10, y: height / 5, width: width * 8 / 10, height: height / 2))
            context.setFillColor(CGColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1))
            for center in [width / 4, width * 3 / 4] {
                context.fillEllipse(in: CGRect(
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
                    CarPictureView(picture: CarVisualPreviewPictures.block(width: 600, height: 200, opaque: false)
                        .map(CarPicture.lifted))
                        .aspectRatio(CarVisual.aspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
                }
                StageSurface {
                    CarPictureView(picture: CarVisualPreviewPictures.block(width: 400, height: 300, opaque: true)
                        .map(CarPicture.whole))
                        .aspectRatio(CarVisual.aspectRatio, contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: DesignTokens.heroCarMaxHeight)
                }
            }
        }
    }
#endif
