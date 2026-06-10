import SwiftData
import SwiftUI

struct InsuranceView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Bindable var policy: InsurancePolicyEntity
    @State private var showEdit = false
    private let themeController = ThemeController()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VWCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(policy.insurer)
                            .font(.headline)
                        Text(LocalizedFormat.string("insurance.policyNumber", policy.policyNumber))
                            .font(.subheadline)
                        Text(LocalizedFormat.string(
                            "insurance.validUntil",
                            LocalizedFormat.date(policy.validUntil)
                        ))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                VWCard {
                    MTSBUQRCodeView(urlString: policy.verificationUrl)
                    if let url = URL(string: policy.verificationUrl) {
                        Button {
                            openURL(url)
                        } label: {
                            Text("insurance.openMTSBU")
                                .font(.caption)
                        }
                        .buttonStyle(.hapticPlain)
                    }
                }
            }
            .padding()
        }
        .background(themeController.screenBackground(for: colorScheme))
        .navigationTitle("insurance.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("common.close") {
                    TapFeedback.light()
                    dismiss()
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button("common.edit") {
                    TapFeedback.light()
                    showEdit = true
                }
                .fontWeight(.semibold)
            }
        }
        .tint(ThemeColors.brand)
        .sheet(isPresented: $showEdit) {
            InsuranceEditSheet(policy: policy)
        }
    }
}

struct InsuranceEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var policy: InsurancePolicyEntity
    @State private var validFrom: Date
    @State private var validUntil: Date
    @State private var policyNumber: String

    init(policy: InsurancePolicyEntity) {
        self.policy = policy
        _validFrom = State(initialValue: policy.validFrom)
        _validUntil = State(initialValue: policy.validUntil)
        _policyNumber = State(initialValue: policy.policyNumber)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("insurance.policyNumberLabel", text: $policyNumber)
                DatePicker("insurance.validFromLabel", selection: $validFrom, displayedComponents: .date)
                DatePicker("insurance.validUntilLabel", selection: $validUntil, displayedComponents: .date)
            }
            .navigationTitle("insurance.edit")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        policy.policyNumber = policyNumber
                        policy.validFrom = validFrom
                        policy.validUntil = validUntil
                        try? modelContext.save()
                        Task { await NotificationRefresh.apply(context: modelContext) }
                        TapFeedback.success()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") {
                        TapFeedback.light()
                        dismiss()
                    }
                }
            }
        }
    }
}
