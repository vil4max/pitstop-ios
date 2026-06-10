import AudioToolbox
import CoreImage
import SwiftUI
import UIKit

enum TapFeedback {
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
}

enum Clipboard {
    static func copy(_ text: String) {
        UIPasteboard.general.string = text
        TapFeedback.success()
    }
}

struct HapticPlainButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed {
                    TapFeedback.light()
                }
            }
    }
}

extension ButtonStyle where Self == HapticPlainButtonStyle {
    static var hapticPlain: HapticPlainButtonStyle { HapticPlainButtonStyle() }
}

enum CompletionFeedback {
    static func playSuccess() {
        AudioServicesPlaySystemSound(1407)
    }
}

struct VWCard<Content: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let theme = ThemeController()
    private let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        content()
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.cardBackground(for: colorScheme))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

struct ThemedToggle<Label: View>: View {
    @Environment(\.colorScheme) private var colorScheme
    private let theme = ThemeController()
    @Binding var isOn: Bool
    var isDisabled: Bool = false
    @ViewBuilder var label: () -> Label

    var body: some View {
        Toggle(isOn: $isOn) {
            label()
        }
        .tint(theme.switchTint(for: colorScheme))
        .disabled(isDisabled)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

extension ThemedToggle where Label == Text {
    init(
        _ title: LocalizedStringKey,
        isOn: Binding<Bool>,
        isDisabled: Bool = false
    ) {
        _isOn = isOn
        self.isDisabled = isDisabled
        label = { Text(title) }
    }
}

struct PrimaryButton: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: LocalizedStringKey
    let action: () -> Void

    private var fillColor: Color {
        colorScheme == .dark ? .white : ThemeColors.brand
    }

    private var labelColor: Color {
        colorScheme == .dark ? ThemeColors.brand : .white
    }

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "checkmark.circle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(labelColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(fillColor)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.12), radius: 8, y: 4)
        }
        .buttonStyle(.hapticPlain)
    }
}

struct SlideToCompleteControl: View {
    @Environment(\.colorScheme) private var colorScheme
    let canComplete: () -> Bool
    let onComplete: () -> Void

    @State private var dragOffset: CGFloat = 0
    @State private var didFinish = false
    @State private var successTrigger = false
    @State private var warningTrigger = false

    private let trackHeight: CGFloat = 56
    private let thumbSide: CGFloat = 48
    private let horizontalInset: CGFloat = 4

    init(canComplete: @escaping () -> Bool = { true }, onComplete: @escaping () -> Void) {
        self.canComplete = canComplete
        self.onComplete = onComplete
    }

    private var trackFill: Color {
        colorScheme == .dark ? .white : ThemeColors.brand
    }

    private var thumbFill: Color {
        colorScheme == .dark ? ThemeColors.brand : .white
    }

    private var hintColor: Color {
        colorScheme == .dark ? ThemeColors.brand.opacity(0.55) : Color.white.opacity(0.85)
    }

    private var thumbIconColor: Color {
        colorScheme == .dark ? .white : ThemeColors.brand
    }

    var body: some View {
        GeometryReader { geometry in
            let maxDrag = max(geometry.size.width - thumbSide - horizontalInset * 2, 0)
            ZStack(alignment: .leading) {
                Capsule(style: .continuous)
                    .fill(trackFill)
                Text("service.slideToComplete")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(hintColor)
                    .frame(maxWidth: .infinity)
                    .opacity(labelOpacity(maxDrag: maxDrag))
                slideThumb(maxDrag: maxDrag)
            }
        }
        .frame(height: trackHeight)
        .sensoryFeedback(.success, trigger: successTrigger)
        .sensoryFeedback(.warning, trigger: warningTrigger)
    }

    private func slideThumb(maxDrag: CGFloat) -> some View {
        Capsule(style: .continuous)
            .fill(thumbFill)
            .frame(width: thumbSide, height: thumbSide)
            .overlay {
                Image(systemName: didFinish ? "checkmark" : "chevron.right.2")
                    .font(.body.weight(.bold))
                    .foregroundStyle(thumbIconColor)
            }
            .shadow(color: Color.black.opacity(0.15), radius: 4, y: 2)
            .offset(x: horizontalInset + dragOffset)
            .gesture(dragGesture(maxDrag: maxDrag))
    }

    private func labelOpacity(maxDrag: CGFloat) -> Double {
        guard maxDrag > 0 else { return 1 }
        return Double(max(0, 1 - dragOffset / maxDrag))
    }

    private func dragGesture(maxDrag: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard !didFinish else { return }
                dragOffset = min(max(0, value.translation.width), maxDrag)
            }
            .onEnded { _ in
                guard !didFinish else { return }
                if dragOffset >= maxDrag * 0.88 {
                    finishSlide(maxDrag: maxDrag)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                        dragOffset = 0
                    }
                }
            }
    }

    private func finishSlide(maxDrag: CGFloat) {
        guard canComplete() else {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                dragOffset = 0
            }
            warningTrigger.toggle()
            return
        }
        didFinish = true
        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
            dragOffset = maxDrag
        }
        CompletionFeedback.playSuccess()
        successTrigger.toggle()
        onComplete()
    }
}

struct CarStatusWidgetCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let symbol: String
    let title: LocalizedStringKey
    let value: String
    let footnote: String?
    var attention: Bool = false

    private var iconColor: Color {
        if attention {
            return Color.orange
        }
        return colorScheme == .dark ? .white : ThemeColors.brand
    }

    private var tileBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.1) : ThemeColors.brand.opacity(0.08)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3.weight(.semibold))
                .foregroundStyle(iconColor)
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(attention ? Color.orange : .primary)
                .fixedSize(horizontal: false, vertical: true)
            if let footnote {
                Text(footnote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: 112, alignment: .topLeading)
        .padding(12)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct OdometerDisplay: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var value: Int
    let updatedAt: Date

    private var digits: [Character] {
        let text = String(format: "%07d", max(value, 0))
        return Array(text)
    }

    private var stepButtonForeground: Color {
        colorScheme == .dark ? .white : ThemeColors.brand
    }

    private var stepButtonBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.2) : ThemeColors.brand.opacity(0.12)
    }

    private var stepButtonBorder: Color {
        colorScheme == .dark ? Color.white.opacity(0.35) : ThemeColors.brand.opacity(0.35)
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(LocalizedFormat.string("odometer.updatedAt", LocalizedFormat.dateTime(updatedAt)))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            HStack(spacing: 8) {
                stepButton("-") { value = max(0, value - 100) }
                HStack(spacing: 4) {
                    ForEach(Array(digits.enumerated()), id: \.offset) { _, digit in
                        Text(String(digit))
                            .font(.title2.monospacedDigit().weight(.semibold))
                            .frame(width: 28, height: 40)
                            .background(Color.black.opacity(0.25))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
                stepButton("+") { value += 100 }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            Text("km")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func stepButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.title2.weight(.bold))
                .foregroundStyle(stepButtonForeground)
                .frame(minWidth: 44, minHeight: 44)
                .background(stepButtonBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(stepButtonBorder, lineWidth: 1)
                }
        }
        .buttonStyle(.hapticPlain)
    }
}

struct MTSBUQRCodeView: View {
    let urlString: String

    var body: some View {
        VStack(spacing: 12) {
            if let image = QRCodeGenerator.makeImage(from: urlString, scale: 12) {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(minWidth: 240, minHeight: 240)
                    .padding(16)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            Text("insurance.mtsbu.caption")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}

enum QRCodeGenerator {
    static func makeImage(from string: String, scale: CGFloat) -> UIImage? {
        guard let data = string.data(using: .utf8),
              let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage else { return nil }
        let transformed = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let context = CIContext()
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
