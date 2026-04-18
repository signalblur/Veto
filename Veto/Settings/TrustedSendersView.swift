import SwiftUI
import VetoCore

struct TrustedSendersView: View {
    @Environment(AppModel.self) private var model
    @State private var showAddSheet = false

    var body: some View {
        Group {
            if model.allowedSenders.isEmpty {
                ContentUnavailableView {
                    Label("No trusted senders", systemImage: "person.crop.circle.badge.plus")
                } description: {
                    Text("Add a sender here, or swipe a History row to trust the sender that sent that message.")
                        .multilineTextAlignment(.center)
                }
            } else {
                List {
                    ForEach(Array(model.allowedSenders).sorted(), id: \.self) { sender in
                        Text(sender).font(.body.monospaced())
                    }
                    .onDelete { offsets in
                        let sorted = Array(model.allowedSenders).sorted()
                        let toRemove = offsets.map { sorted[$0] }
                        Task { await model.removeTrustedSenders(toRemove) }
                    }
                }
            }
        }
        .navigationTitle("Trusted Senders")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddTrustedSenderSheet()
        }
    }
}

private struct AddTrustedSenderSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var sender = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("+1 555 555 0100", text: $sender)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                } footer: {
                    Text("Enter the number in E.164 format (with country code) for best results. iOS passes inbound numbers to filters in this format.")
                }
            }
            .navigationTitle("Trust a sender")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        Task {
                            await model.addTrustedSender(sender)
                            dismiss()
                        }
                    }
                    .disabled(sender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
