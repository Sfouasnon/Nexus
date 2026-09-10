import Foundation
import Network
import Observation

enum HyperDeckConnectionState: String, Sendable {
    case offline = "Offline"
    case connecting = "Connecting"
    case connected = "Connected"
}

@MainActor @Observable
final class DirectHyperDeckStore: Identifiable {
    let id: String
    var name: String { didSet { defaults.set(name, forKey: "name") } }
    var host: String { didSet { defaults.set(host, forKey: "host") } }
    private(set) var connectionState: HyperDeckConnectionState = .offline
    private(set) var model = "HyperDeck"
    private(set) var transport = "stopped"
    private(set) var speed = "0"
    private(set) var slot = "—"
    private(set) var timecode = "00:00:00:00"
    private(set) var message = "Enter the HyperDeck IP address to connect."

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let demo: Bool
    @ObservationIgnored private let queue: DispatchQueue
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private var buffer = Data()

    init(id: String, number: Int, demo: Bool) {
        self.id = id
        self.demo = demo
        defaults = UserDefaults(suiteName: "com.local.nexus-control.hyperdeck.\(id)")!
        name = defaults.string(forKey: "name") ?? "HyperDeck \(number)"
        host = defaults.string(forKey: "host") ?? ""
        queue = DispatchQueue(label: "com.local.nexus.hyperdeck.\(id)")
        if demo {
            connectionState = .connected
            model = "HyperDeck Studio HD Mini — Demo"
            transport = "stopped"
            slot = "1"
            timecode = "00:12:34:10"
            message = "Demo mode — no HyperDeck commands are sent."
        }
    }

    func connect() {
        guard !demo else { return }
        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { message = "Enter a HyperDeck IP address."; return }
        disconnect()
        connectionState = .connecting
        message = "Connecting to \(target):9993…"
        let connection = NWConnection(host: NWEndpoint.Host(target), port: 9993, using: .tcp)
        self.connection = connection
        connection.stateUpdateHandler = { [weak self, weak connection] state in
            Task { @MainActor in
                guard let self, self.connection === connection else { return }
                switch state {
                case .ready:
                    self.connectionState = .connected
                    self.message = "Connected over the HyperDeck Ethernet Protocol."
                    self.receive()
                    self.send("remote: enable: true")
                    self.send("device info")
                    self.send("transport info")
                    self.send("slot info")
                    self.send("notify: transport: true slot: true")
                case .failed(let error):
                    self.connectionState = .offline
                    self.message = "Connection failed: \(error.localizedDescription)"
                    self.connection = nil
                case .cancelled:
                    self.connectionState = .offline
                default: break
                }
            }
        }
        connection.start(queue: queue)
    }

    func disconnect() {
        connection?.cancel()
        connection = nil
        buffer.removeAll(keepingCapacity: true)
        if !demo {
            connectionState = .offline
            message = "Disconnected."
        }
    }

    func play() { command("play") }
    func stop() { command("stop") }
    func record() { command("record") }
    func previousClip() { command("goto: clip id: -1") }
    func nextClip() { command("goto: clip id: +1") }

    private func command(_ text: String) {
        if demo {
            transport = text == "record" ? "record" : text == "stop" ? "stopped" : text == "play" ? "play" : transport
            message = "Demo command: \(text)"
        } else if connectionState == .connected {
            send(text)
        }
    }

    private func send(_ command: String) {
        connection?.send(content: Data("\(command)\r\n".utf8), completion: .contentProcessed { [weak self] error in
            guard let error else { return }
            Task { @MainActor in self?.message = "Command failed: \(error.localizedDescription)" }
        })
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self] data, _, complete, error in
            Task { @MainActor in
                guard let self else { return }
                if let data { self.buffer.append(data); self.consumeBlocks() }
                if let error { self.message = "Connection lost: \(error.localizedDescription)"; self.disconnect(); return }
                if complete { self.message = "HyperDeck closed the connection."; self.disconnect(); return }
                self.receive()
            }
        }
    }

    private func consumeBlocks() {
        let separator = Data("\r\n\r\n".utf8)
        while let range = buffer.range(of: separator) {
            let data = buffer.subdata(in: buffer.startIndex..<range.lowerBound)
            buffer.removeSubrange(buffer.startIndex..<range.upperBound)
            parse(String(decoding: data, as: UTF8.self))
        }
    }

    private func parse(_ block: String) {
        var values: [String: String] = [:]
        for line in block.components(separatedBy: "\r\n").dropFirst() {
            guard let colon = line.firstIndex(of: ":") else { continue }
            values[String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()] =
                String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        if let value = values["model"] { model = value }
        if let value = values["status"] { transport = value }
        if let value = values["speed"] { speed = value }
        if let value = values["slot id"] { slot = value }
        if let value = values["display timecode"] ?? values["timecode"] { timecode = value }
        if block.hasPrefix("200 ") { message = "Command accepted." }
        if block.hasPrefix("1") { message = block.components(separatedBy: "\r\n").first ?? "HyperDeck error" }
    }
}
