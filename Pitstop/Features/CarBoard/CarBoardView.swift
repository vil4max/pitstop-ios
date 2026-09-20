import SwiftUI

struct CarBoardView: View {
    let viewModel: CarBoardViewModel

    @State private var isEditingCar = false

    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.tileSpacing) {
                    if viewModel.state.isStorageTemporary {
                        Label("carBoard.storage.temporary", systemImage: "externaldrive.badge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    if viewModel.state.isLoadFailed {
                        HStack {
                            Label("carBoard.load.failed", systemImage: "exclamationmark.arrow.circlepath")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("carBoard.load.retry") {
                                Task { await viewModel.load() }
                            }
                            .font(.footnote.weight(.semibold))
                        }
                    }
                    Button {
                        isEditingCar = true
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.state.car.name)
                                .font(.largeTitle.bold())
                            mileageText
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("carBoard.hero.editHint")
                    .accessibilityIdentifier("carBoard.hero")
                    placeholderTiles
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(DesignTokens.screenPadding)
                .padding(.bottom, 80)
            }
            utilityLayer
        }
        .task { await viewModel.load() }
        .sheet(isPresented: $isEditingCar) {
            CarEditorView(car: viewModel.state.car) { name, odometer in
                await viewModel.saveCar(name: name, odometerText: odometer)
            }
            .alert(failureTitle, isPresented: failureBinding) {
                Button("common.ok") { viewModel.dismissFailure() }
            }
        }
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

    private var mileageText: Text {
        switch viewModel.state.mileage {
        case .unknown:
            Text("carBoard.mileage.unknown")
        case let .kilometers(value):
            Text("carBoard.mileage.km \(value)")
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
