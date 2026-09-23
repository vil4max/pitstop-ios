import SwiftUI

struct CarBoardView: View {
    let viewModel: CarBoardViewModel

    @State private var isEditingCar = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                notices
                // VoiceOver reads the heading, the hero's mileage and its one action, then the tiles
                // (REQ-BOARD-022); the car drawing itself is decorative.
                ScreenHeader(eyebrow: String(localized: "carBoard.eyebrow"), title: viewModel.state.car.name)
                CarHeroView(
                    car: viewModel.state.car,
                    mileage: viewModel.state.mileage,
                    recency: viewModel.state.mileageRecency
                ) {
                    isEditingCar = true
                }
                .padding(.bottom, DesignTokens.sectionSpacing - DesignTokens.tileSpacing)

                ForEach(CarBoardTileDescriptor.rows(), id: \.first?.kind) { row in
                    tileRow(row)
                }
            }
            .padding(.horizontal, DesignTokens.screenPadding)
            .padding(.bottom, DesignTokens.tileSpacing)
        }
        .pitReportsScrolling()
        .background(PitColor.surfacePrimary)
        .task { await viewModel.load() }
        .pitActivity(.modalTask, while: isEditingCar)
        .sheet(isPresented: $isEditingCar) {
            CarEditorView(car: viewModel.state.car) { name, odometer in
                await viewModel.saveCar(name: name, odometerText: odometer)
            }
            .alert(failureTitle, isPresented: failureBinding) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
    }

    @ViewBuilder
    private var notices: some View {
        if viewModel.state.isStorageTemporary {
            Label("carBoard.storage.temporary", systemImage: "externaldrive.badge.exclamationmark")
                .font(.footnote)
                .foregroundStyle(PitColor.contentSecondary)
        }
        if viewModel.state.isLoadFailed {
            LoadFailureBanner(message: "carBoard.load.failed") { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func tileRow(_ row: [CarBoardTileDescriptor]) -> some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Half width cannot hold large text; the order stays the same, one tile per row.
            ForEach(row) { tileLink($0) }
        } else {
            HStack(alignment: .top, spacing: DesignTokens.tileSpacing) {
                ForEach(row) { tileLink($0) }
                if row.count == 1, row.first?.size == .half {
                    // Future slot: left empty on purpose rather than filled with a fake tile.
                    Color.clear.frame(maxWidth: .infinity)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func tileLink(_ descriptor: CarBoardTileDescriptor) -> some View {
        NavigationLink(value: CarBoardRoute.tile(descriptor.kind)) {
            CarBoardTileView(
                descriptor: descriptor,
                notes: viewModel.state.notes,
                history: viewModel.state.history,
                service: viewModel.state.service,
                road: viewModel.state.road
            )
        }
        .buttonStyle(.plain)
        // On the link itself, so VoiceOver gets one button whose label is the tile's summary.
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("carBoard.tile.\(descriptor.kind.rawValue)")
    }

    private var failureBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.failure != nil },
            set: {
                if !$0 {
                    viewModel.dismissFailure()
                }
            }
        )
    }

    private var failureTitle: LocalizedStringKey {
        switch viewModel.state.failure {
        case .invalidOdometer: "carEditor.failure.odometer"
        case .mileageNotSaved: "carEditor.failure.mileageOnly"
        case .saveFailed, .none: "carEditor.failure.save"
        }
    }
}

/// Car Board mileage presentation; a missing reading must never render as `0 km`.
enum CarBoardMileage: Equatable {
    case unknown
    case kilometers(Int)

    init(odometerKm: Int?) {
        if let odometerKm {
            self = .kilometers(odometerKm)
        } else {
            self = .unknown
        }
    }
}
