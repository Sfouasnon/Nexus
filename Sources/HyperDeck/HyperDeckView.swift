import SwiftUI

struct DirectHyperDeckView: View {
    @Bindable var store: DirectHyperDeckStore

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    TextField("Device name", text: $store.name)
                        .textFieldStyle(.plain).font(.title2.bold()).frame(width: 280)
                    Text(store.model).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                TextField("HyperDeck IP address", text: $store.host)
                    .textFieldStyle(.roundedBorder).frame(width: 230)
                Button(store.connectionState == .offline ? "Connect" : "Disconnect") {
                    store.connectionState == .offline ? store.connect() : store.disconnect()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(20)
            Divider()
            VStack(spacing: 28) {
                HStack(spacing: 36) {
                    statusCard("STATUS", store.transport.uppercased())
                    statusCard("TIMECODE", store.timecode)
                    statusCard("ACTIVE SLOT", store.slot)
                    statusCard("SPEED", "\(store.speed)%")
                }
                HStack(spacing: 12) {
                    Button { store.previousClip() } label: { Label("Previous", systemImage: "backward.end.fill") }
                    Button { store.stop() } label: { Label("Stop", systemImage: "stop.fill") }
                    Button { store.play() } label: { Label("Play", systemImage: "play.fill") }
                        .buttonStyle(.borderedProminent).tint(.green)
                    Button { store.record() } label: { Label("Record", systemImage: "record.circle") }
                        .buttonStyle(.borderedProminent).tint(.red)
                    Button { store.nextClip() } label: { Label("Next", systemImage: "forward.end.fill") }
                }
                .controlSize(.large)
                Text(store.message).font(.callout).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(30)
        }
        .background(Color(red: 0.035, green: 0.05, blue: 0.07))
    }

    private func statusCard(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(.caption.bold()).foregroundStyle(.secondary)
            Text(value).font(.system(size: 19, weight: .semibold, design: .monospaced))
        }
        .frame(minWidth: 150, alignment: .leading).padding(18)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.09)))
    }
}
