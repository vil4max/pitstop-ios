#if DEBUG
    import SwiftUI

    /// The design-system preview matrix (design-system-module.md): light and dark, each at the default text
    /// size and at accessibility extra large.
    struct PreviewMatrix<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Variant.allCases, id: \.self) { variant in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(verbatim: variant.caption)
                                .font(PitTypography.captionSmall)
                                .foregroundStyle(PitColor.contentSecondary)
                            content
                        }
                        .padding(DesignTokens.screenPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(PitColor.surfacePrimary)
                        .environment(\.colorScheme, variant.colorScheme)
                        .environment(\.dynamicTypeSize, variant.dynamicTypeSize)
                    }
                }
            }
        }

        enum Variant: CaseIterable {
            case light, dark, lightAccessibility, darkAccessibility

            var colorScheme: ColorScheme {
                self == .light || self == .lightAccessibility ? .light : .dark
            }

            var dynamicTypeSize: DynamicTypeSize {
                self == .light || self == .dark ? .large : .accessibility3
            }

            var caption: String {
                switch self {
                case .light: "Light"
                case .dark: "Dark"
                case .lightAccessibility: "Light, AX-XL"
                case .darkAccessibility: "Dark, AX-XL"
                }
            }
        }
    }
#endif
