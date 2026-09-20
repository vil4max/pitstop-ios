import SwiftUI

/// Shared header grammar: eyebrow / context, then a large title.
struct ScreenHeader: View {
    let eyebrow: String
    let title: String

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(eyebrow)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .kerning(0.8)
                .foregroundStyle(PitColor.contentSecondary)
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
}
