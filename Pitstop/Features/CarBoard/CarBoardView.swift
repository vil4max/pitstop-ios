import SwiftUI

struct CarBoardView: View {
    let carContext: ProvisionalCarContext

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                    Text(carContext.name)
                        .font(.largeTitle.bold())
                    Text("\(carContext.odometerKm) km")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    placeholderTiles
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.screenPadding)
                .padding(.bottom, 80)
            }
            utilityLayer
        }
    }

    private var placeholderTiles: some View {
        VStack(spacing: DesignTokens.tileSpacing) {
            tilePlaceholder(title: "Road")
            HStack(spacing: DesignTokens.tileSpacing) {
                tilePlaceholder(title: "Notes")
                tilePlaceholder(title: "Service")
            }
            tilePlaceholder(title: "History")
        }
    }

    private func tilePlaceholder(title: String) -> some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.quaternary)
            .frame(height: title == "Road" ? 120 : 88)
            .overlay(alignment: .leading) {
                Text(title)
                    .font(.headline)
                    .padding()
            }
    }

    private var utilityLayer: some View {
        HStack {
            Image(systemName: "gearshape")
                .font(.title2)
                .frame(width: DesignTokens.utilityButtonSize, height: DesignTokens.utilityButtonSize)
                .accessibilityLabel("Settings")
            Spacer()
            Image(systemName: "eye")
                .font(.title2)
                .frame(width: DesignTokens.utilityButtonSize, height: DesignTokens.utilityButtonSize)
                .accessibilityLabel("Pit")
        }
        .padding(.horizontal, DesignTokens.screenPadding)
        .padding(.bottom, 8)
    }
}
