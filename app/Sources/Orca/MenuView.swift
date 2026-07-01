import OrcaCore
import SwiftUI

struct MenuView: View {
    @EnvironmentObject var store: AgentStore
    let onSelectAgent: (Agent) -> Void
    let onDismissAgent: (Agent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Orca").font(.headline)
                Spacer()
                Text("\(store.runningCount) active · \(store.openSessionCount) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Divider()

            if store.agents.isEmpty {
                Text("No active agents")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 6)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(store.agents) { agent in
                            row(for: agent, now: context.date)
                        }
                    }
                }
            }

            Divider()

            HStack {
                Button("Clear finished") { store.clearFinished() }
                    .disabled(!store.hasFinished)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
            }
            .font(.caption)
        }
        .padding(14)
        .frame(width: 320)
    }

    @ViewBuilder
    private func row(for agent: Agent, now: Date) -> some View {
        HStack(alignment: .top, spacing: 8) {
            HStack(alignment: .top, spacing: 9) {
                Circle()
                    .fill(color(for: agent.status))
                    .frame(width: 9, height: 9)
                    .padding(.top, 4)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(agent.title).fontWeight(.medium).lineLimit(1)
                        Spacer(minLength: 4)
                        Text(formatDuration(agent.duration(now: now)))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Text("\(agent.source) · \(label(for: agent.status))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if let message = agent.message, !message.isEmpty {
                        Text(message).font(.caption2).foregroundStyle(.secondary).lineLimit(2)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture { onSelectAgent(agent) }
            .help(agent.tty.map { "Jump to terminal (\($0))" } ?? "Jump to terminal")

            Button {
                onDismissAgent(agent)
            } label: {
                Image(systemName: "xmark.circle.fill").font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tertiary)
            .help("Dismiss")
        }
    }

    private func color(for status: AgentStatus) -> Color {
        switch status {
        case .running: return .blue
        case .waiting: return .orange
        case .done: return .green
        case .error: return .red
        case .idle: return .gray
        }
    }

    private func label(for status: AgentStatus) -> String {
        switch status {
        case .running: return "running"
        case .waiting: return "waiting for input"
        case .done: return "done"
        case .error: return "error"
        case .idle: return "idle"
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let total = Int(interval)
        if total < 60 { return "\(total)s" }
        let minutes = total / 60
        let seconds = total % 60
        if minutes < 60 {
            return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins == 0 ? "\(hours)h" : "\(hours)h \(mins)m"
    }
}
