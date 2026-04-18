import SwiftUI
import VetoCore

struct HistoryView: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        NavigationStack {
            Group {
                if model.historyEntries.isEmpty {
                    ContentUnavailableView {
                        Label("No history yet", systemImage: "tray")
                    } description: {
                        Text("Once Veto is enabled in iOS Settings → Messages → Unknown & Spam → SMS Filtering, decisions will appear here.")
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(model.historyEntries, id: \.bodyHash) { entry in
                            HistoryRow(entry: entry)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        Task { await model.addTrustedSender(entry.sender) }
                                    } label: {
                                        Label("Trust sender", systemImage: "person.crop.circle.badge.checkmark")
                                    }
                                    .tint(.blue)
                                }
                                .swipeActions(edge: .trailing) {
                                    if !entry.undone {
                                        Button {
                                            Task { await model.markEntryUndone(entry) }
                                        } label: {
                                            Label("Mistake", systemImage: "arrow.uturn.backward")
                                        }
                                        .tint(.orange)
                                    }
                                }
                        }
                    }
                    .refreshable { await model.reloadHistory() }
                }
            }
            .navigationTitle("History")
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: actionSymbol)
                    .foregroundStyle(actionColor)
                Text(entry.sender)
                    .font(.body.monospaced())
                Spacer()
                Text(entry.timestamp, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 8) {
                Text(actionLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(actionColor)
                if let detail = actionDetail {
                    Text(detail)
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                if entry.undone {
                    Text("UNDONE")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var actionSymbol: String {
        switch entry.action {
        case .junk: return "trash.fill"
        case .allow: return "checkmark.shield.fill"
        case .none: return "circle"
        }
    }

    private var actionColor: Color {
        switch entry.action {
        case .junk: return .red
        case .allow: return .green
        case .none: return .secondary
        }
    }

    private var actionLabel: String {
        switch entry.action {
        case .junk: return "Junked"
        case .allow: return "Allowed"
        case .none: return "Passed"
        }
    }

    private var actionDetail: String? {
        switch entry.action {
        case .junk(let ruleId): return ruleId
        case .allow(let reason): return reason
        case .none: return nil
        }
    }
}
