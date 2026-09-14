import AppKit
import SwiftUI
import Observation

enum HardwareKind: String, CaseIterable {
    case atem = "ATEM"
    case videohub = "Videohub"
    case hyperdeck = "HyperDeck"

    var icon: String {
        switch self {
        case .atem: "slider.horizontal.3"
        case .videohub: "square.grid.3x3"
        case .hyperdeck: "record.circle"
        }
    }
}

@MainActor @Observable
final class ATEMSession: Identifiable {
    let id: String
    var name: String { didSet { defaults.set(name, forKey: "name") } }
    var page = "switcher"
    let bridge: NexusBridge
    private let defaults: UserDefaults

    init(id: String, number: Int, demo: Bool) {
        self.id = id
        defaults = UserDefaults(suiteName: "com.local.nexus-control.atem.\(id)")!
        name = defaults.string(forKey: "name") ?? "ATEM \(number)"
        bridge = NexusBridge(demo: demo, identifier: id)
        bridge.featureHandler = { [weak self] feature, _ in self?.page = feature }
    }

    var status: String { bridge.status(0) }
}

@MainActor @Observable
final class RouterSession: Identifiable {
    let id: String
    var name: String { didSet { defaults.set(name, forKey: "name") } }
    let store: RouterStore
    let bridge: ControlBridge
    private let defaults: UserDefaults

    init(id: String, number: Int, demo: Bool, customizations: CustomizationStore, salvos: SalvoStore) {
        self.id = id
        let defaults = UserDefaults(suiteName: "com.local.nexus-control.router.\(id)")!
        self.defaults = defaults
        name = defaults.string(forKey: "name") ?? "Videohub \(number)"
        // First use waits for an explicit Connect; persisted reconnect preferences are honored.
        defaults.register(defaults: ["videohub.reconnectAutomatically": false, "control.port": 5399 + number])
        store = RouterStore(defaults: defaults, customizationStore: customizations,
                            salvoStore: salvos, demoPortCount: demo ? 16 : nil)
        bridge = ControlBridge(store: store, defaults: defaults)
        store.start()
        if !demo { bridge.start() }
    }
}

@MainActor @Observable
final class Workspace {
    let demo: Bool
    var atems: [ATEMSession] = []
    var routers: [RouterSession] = []
    var hyperdecks: [DirectHyperDeckStore] = []
    var selection = ""
    var settings = false
    var refreshToken = 0
    let customizations: CustomizationStore
    let salvos: SalvoStore

    init(demo: Bool) {
        self.demo = demo
        customizations = CustomizationStore()
        salvos = SalvoStore()

        let atemIDs = UserDefaults.standard.stringArray(forKey: "nexus.atems") ?? ["primary", "secondary"]
        migrateLegacyATEMAddresses(to: atemIDs)
        atems = atemIDs.enumerated().map { ATEMSession(id: $0.element, number: $0.offset + 1, demo: demo) }

        let routerIDs = UserDefaults.standard.stringArray(forKey: "nexus.routers") ?? ["primary"]
        routers = routerIDs.enumerated().map { RouterSession(id: $0.element, number: $0.offset + 1,
            demo: demo, customizations: customizations, salvos: salvos) }

        let hyperDeckIDs = UserDefaults.standard.stringArray(forKey: "nexus.hyperdecks") ?? []
        hyperdecks = hyperDeckIDs.enumerated().map {
            DirectHyperDeckStore(id: $0.element, number: $0.offset + 1, demo: demo)
        }
        selection = atems.first.map { "atem:\($0.id)" }
            ?? routers.first.map { "videohub:\($0.id)" }
            ?? hyperdecks.first.map { "hyperdeck:\($0.id)" } ?? ""
    }

    func refresh() { refreshToken &+= 1 }

    func addHardware(_ kind: HardwareKind) {
        let id = UUID().uuidString
        switch kind {
        case .atem:
            let device = ATEMSession(id: id, number: atems.count + 1, demo: demo)
            atems.append(device)
            UserDefaults.standard.set(atems.map(\.id), forKey: "nexus.atems")
            selection = "atem:\(id)"
        case .videohub:
            let device = RouterSession(id: id, number: routers.count + 1,
                demo: demo, customizations: customizations, salvos: salvos)
            routers.append(device)
            UserDefaults.standard.set(routers.map(\.id), forKey: "nexus.routers")
            selection = "videohub:\(id)"
        case .hyperdeck:
            let device = DirectHyperDeckStore(id: id, number: hyperdecks.count + 1, demo: demo)
            hyperdecks.append(device)
            UserDefaults.standard.set(hyperdecks.map(\.id), forKey: "nexus.hyperdecks")
            selection = "hyperdeck:\(id)"
        }
    }

    var selectedHardwareName: String {
        if let id = selection.removingPrefix("atem:"),
           let device = atems.first(where: { $0.id == id }) { return device.name }
        if let id = selection.removingPrefix("videohub:"),
           let device = routers.first(where: { $0.id == id }) { return device.name }
        if let id = selection.removingPrefix("hyperdeck:"),
           let device = hyperdecks.first(where: { $0.id == id }) { return device.name }
        return "Hardware"
    }

    func removeSelectedHardware() {
        let selectionsBeforeRemoval = hardwareSelections
        let removedIndex = selectionsBeforeRemoval.firstIndex(of: selection) ?? 0

        if let id = selection.removingPrefix("atem:"),
           let index = atems.firstIndex(where: { $0.id == id }) {
            atems[index].bridge.shutdown()
            atems.remove(at: index)
            clearDefaults(suite: "com.local.nexus-control.atem.\(id)")
            UserDefaults.standard.removeObject(forKey: "nexus.atem.\(id).0.address")
            UserDefaults.standard.removeObject(forKey: "nexus.atem.\(id).1.address")
            UserDefaults.standard.set(atems.map(\.id), forKey: "nexus.atems")
        } else if let id = selection.removingPrefix("videohub:"),
                  let index = routers.firstIndex(where: { $0.id == id }) {
            routers[index].store.disconnect()
            routers[index].bridge.shutdown()
            routers.remove(at: index)
            clearDefaults(suite: "com.local.nexus-control.router.\(id)")
            UserDefaults.standard.set(routers.map(\.id), forKey: "nexus.routers")
            settings = false
        } else if let id = selection.removingPrefix("hyperdeck:"),
                  let index = hyperdecks.firstIndex(where: { $0.id == id }) {
            hyperdecks[index].disconnect()
            hyperdecks.remove(at: index)
            clearDefaults(suite: "com.local.nexus-control.hyperdeck.\(id)")
            UserDefaults.standard.set(hyperdecks.map(\.id), forKey: "nexus.hyperdecks")
        }

        let remaining = hardwareSelections
        selection = remaining.isEmpty ? "" : remaining[min(removedIndex, remaining.count - 1)]
    }

    private var hardwareSelections: [String] {
        atems.map { "atem:\($0.id)" }
            + routers.map { "videohub:\($0.id)" }
            + hyperdecks.map { "hyperdeck:\($0.id)" }
    }

    private func clearDefaults(suite: String) {
        UserDefaults.standard.removePersistentDomain(forName: suite)
    }

    func addRouter() {
        addHardware(.videohub)
    }

    private func migrateLegacyATEMAddresses(to ids: [String]) {
        let defaults = UserDefaults.standard
        for (index, id) in ids.prefix(2).enumerated() {
            let destination = "nexus.atem.\(id).0.address"
            guard defaults.string(forKey: destination) == nil else { continue }
            if let address = defaults.string(forKey: "lastSwitcherAddress.\(index)"), !address.isEmpty {
                defaults.set(address, forKey: destination)
            }
        }
    }
}

private extension String {
    func removingPrefix(_ prefix: String) -> String? {
        guard hasPrefix(prefix) else { return nil }
        return String(dropFirst(prefix.count))
    }
}

struct ATEMPanel: NSViewRepresentable {
    let bridge: NexusBridge
    let feature: String
    let session: Int
    let window: NSWindow
    final class Coordinator { var key = "" }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ container: NSView, context: Context) {
        let key = "\(feature)-\(session)"
        guard context.coordinator.key != key else { return }
        context.coordinator.key = key
        let surface = bridge.surface(feature, session: UInt(session), window: window)
        guard container.subviews.first !== surface else { return }
        container.subviews.forEach { $0.removeFromSuperview() }
        surface.removeFromSuperview()
        surface.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(surface)
        NSLayoutConstraint.activate([
            surface.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            surface.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            surface.topAnchor.constraint(equalTo: container.topAnchor),
            surface.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
    }
}

struct NexusSurface: View {
    @Bindable var workspace: Workspace
    let window: NSWindow
    @State private var showingRemoveConfirmation = false
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let brandLogo = Bundle.main.url(forResource: "Nexus-AppIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
    private let pages = [("switcher", "Switcher"), ("audio", "Audio"), ("color", "Camera / Color"),
                         ("labels", "Labels"), ("media", "Media"), ("hyperdeck", "HyperDecks")]
    var body: some View {
        let _ = workspace.refreshToken
        VStack(spacing: 0) {
            HStack(spacing: 20) {
                HStack(spacing: 8) {
                    if let logo = Self.brandLogo {
                        Image(nsImage: logo)
                            .resizable().scaledToFit().frame(width: 42, height: 42)
                            .accessibilityLabel("Nexus Signal N logo")
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("NEXUS").font(.system(size: 18, weight: .bold, design: .rounded)).tracking(3)
                        Text("HARDWARE CONTROL").font(.system(size: 8, weight: .semibold)).tracking(1.6).foregroundStyle(.secondary)
                    }
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(workspace.atems) { atem in
                            hardwareTab(atem.name, id: "atem:\(atem.id)", icon: HardwareKind.atem.icon,
                                status: atem.status)
                        }
                        ForEach(workspace.routers) { router in
                            hardwareTab(router.name, id: "videohub:\(router.id)", icon: HardwareKind.videohub.icon,
                                status: workspace.demo ? "Demo" : router.store.connectionState.label)
                        }
                        ForEach(workspace.hyperdecks) { deck in
                            hardwareTab(deck.name, id: "hyperdeck:\(deck.id)", icon: HardwareKind.hyperdeck.icon,
                                status: deck.connectionState.rawValue)
                        }
                    }
                }
                Menu {
                    ForEach(HardwareKind.allCases, id: \.self) { kind in
                        Button { workspace.addHardware(kind) } label: {
                            Label(kind.rawValue, systemImage: kind.icon)
                        }
                    }
                } label: {
                    Label("Add Hardware", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("Add an ATEM, Videohub, or standalone HyperDeck")
                .accessibilityLabel("Add Hardware")
                .accessibilityIdentifier("add-hardware-menu")
                Button {
                    showingRemoveConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Remove the selected hardware connection")
                .accessibilityLabel("Remove Hardware")
                .accessibilityIdentifier("remove-hardware-button")
                .disabled(workspace.selection.isEmpty)
                if workspace.demo { Text("DEMO").font(.caption.bold()).foregroundStyle(.orange) }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color(red: 0.055, green: 0.075, blue: 0.10))
            Divider()
            ZStack {
            VStack(spacing: 0) {
            if let atem = selectedATEM {
                HStack(spacing: 8) {
                    ForEach(pages, id: \.0) { page in
                        Button(page.1) { atem.page = page.0 }
                            .buttonStyle(.bordered)
                            .tint(atem.page == page.0 ? .cyan : .gray)
                    }
                    Spacer()
                    TextField("Device name", text: Binding(get: { atem.name }, set: { atem.name = $0 }))
                        .textFieldStyle(.plain).font(.caption.bold()).multilineTextAlignment(.trailing).frame(width: 180)
                }.padding(10)
                ATEMPanel(bridge: atem.bridge, feature: atem.page, session: 0, window: window)
                    .id("atem-panel-\(atem.id)")
            } else if let deck = selectedHyperDeck {
                DirectHyperDeckView(store: deck)
            } else if workspace.selection.isEmpty {
                ContentUnavailableView {
                    Label("No Hardware", systemImage: "cable.connector.slash")
                } description: {
                    Text("Use Add Hardware to create an ATEM, Videohub, or HyperDeck connection.")
                }
            }
            }
                // Keep each hosting subtree alive so search, page and routing selection survive tab changes.
                ZStack {
                    ForEach(workspace.routers) { router in
                        VStack(spacing: 0) {
                            HStack {
                                TextField("Device name", text: Binding(get: { router.name }, set: { router.name = $0 }))
                                    .textFieldStyle(.plain).font(.headline).frame(width: 240)
                                Spacer()
                                Button("Router Settings") { workspace.settings = true }
                            }.padding(12)
                            ContentView(store: router.store)
                        }
                        .opacity(workspace.selection == "videohub:\(router.id)" ? 1 : 0)
                        .disabled(workspace.selection != "videohub:\(router.id)")
                        .allowsHitTesting(workspace.selection == "videohub:\(router.id)")
                        .accessibilityHidden(workspace.selection != "videohub:\(router.id)")
                    }
                }
                .opacity(selectedRouter != nil ? 1 : 0)
                .allowsHitTesting(selectedRouter != nil)
                .accessibilityHidden(selectedRouter == nil)
            }
        }
        .frame(minWidth: 1180, minHeight: 800)
        .background(Color(red: 0.035, green: 0.05, blue: 0.07))
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in workspace.refresh() }
        .sheet(isPresented: $workspace.settings) {
            if let router = selectedRouter {
                VStack {
                    HStack { Text("\(router.name) Settings").font(.headline); Spacer(); Button("Done") { workspace.settings = false } }.padding()
                    SettingsView(store: router.store, bridge: router.bridge)
                }.frame(minWidth: 720, minHeight: 550).preferredColorScheme(.dark)
            }
        }
        .confirmationDialog("Remove \(workspace.selectedHardwareName)?",
                            isPresented: $showingRemoveConfirmation,
                            titleVisibility: .visible) {
            Button("Remove \(workspace.selectedHardwareName)", role: .destructive) {
                workspace.removeSelectedHardware()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This disconnects the device and deletes its saved Nexus connection settings.")
        }
    }

    private var selectedATEM: ATEMSession? {
        guard workspace.selection.hasPrefix("atem:") else { return nil }
        return workspace.atems.first { workspace.selection == "atem:\($0.id)" }
    }

    private var selectedRouter: RouterSession? {
        guard workspace.selection.hasPrefix("videohub:") else { return nil }
        return workspace.routers.first { workspace.selection == "videohub:\($0.id)" }
    }

    private var selectedHyperDeck: DirectHyperDeckStore? {
        guard workspace.selection.hasPrefix("hyperdeck:") else { return nil }
        return workspace.hyperdecks.first { workspace.selection == "hyperdeck:\($0.id)" }
    }
    private func hardwareTab(_ name: String, id: String, icon: String, status: String) -> some View {
        Button {
            window.makeFirstResponder(nil)
            workspace.selection = id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon).foregroundStyle(workspace.selection == id ? .cyan : .secondary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(name).font(.system(size: 12, weight: .semibold))
                    HStack(spacing: 4) {
                        Circle().fill(status == "Connected" ? Color.green : status == "Demo" ? .orange : .gray).frame(width: 5, height: 5)
                        Text(status).font(.system(size: 9)).foregroundStyle(.secondary)
                    }
                }
            }.padding(.horizontal, 14).padding(.vertical, 9)
                .background(workspace.selection == id ? Color.white.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: 7))
                .overlay(alignment: .bottom) { if workspace.selection == id { Capsule().fill(.cyan).frame(height: 2).padding(.horizontal, 12) } }
        }.buttonStyle(.plain).accessibilityIdentifier("tab-\(id)")
    }
}

@main
@MainActor
final class NexusApp: NSObject, NSApplicationDelegate {
    private var window: NSWindow!
    private var workspace: Workspace!
    static func main() {
        let app = NSApplication.shared
        let delegate = NexusApp()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = ProcessInfo.processInfo.arguments
        workspace = Workspace(demo: args.contains("--demo"))
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1380, height: 940),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Nexus — Blackmagic Hardware Control"
        window.appearance = NSAppearance(named: .darkAqua)
        window.minSize = NSSize(width: 1180, height: 830)
        window.tabbingMode = .disallowed
        window.contentView = NSHostingView(rootView: NexusSurface(workspace: workspace, window: window))
        window.center()
        window.setFrameAutosaveName("Nexus.Main")
        installMenu()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        if let i = args.firstIndex(of: "--preview-tab"), args.indices.contains(i + 1) {
            let requested = args[i + 1]
            if requested == "primary" { workspace.selection = "videohub:primary" }
            else if requested == "hyperdeck", let deck = workspace.hyperdecks.first {
                workspace.selection = "hyperdeck:\(deck.id)"
            } else { workspace.selection = requested }
        }
        if let i = args.firstIndex(of: "--capture-ui"), args.indices.contains(i + 1) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [self] in
                let view = window.contentView!
                view.layoutSubtreeIfNeeded()
                guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
                view.cacheDisplay(in: view.bounds, to: bitmap)
                try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: args[i + 1]))
                NSApp.terminate(nil)
            }
        }
    }
    private func installMenu() {
        let main = NSMenu()
        let app = NSMenuItem(); main.addItem(app); app.submenu = NSMenu(title: "Nexus")
        app.submenu?.addItem(withTitle: "Quit Nexus", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let edit = NSMenuItem(); main.addItem(edit); edit.submenu = NSMenu(title: "Edit")
        for (title, selector, key) in [("Undo", "undo:", "z"), ("Cut", "cut:", "x"), ("Copy", "copy:", "c"), ("Paste", "paste:", "v"), ("Select All", "selectAll:", "a")] {
            edit.submenu?.addItem(withTitle: title, action: NSSelectorFromString(selector), keyEquivalent: key)
        }
        NSApp.mainMenu = main
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        for atem in workspace.atems { atem.bridge.shutdown() }
        for router in workspace.routers { router.store.disconnect() }
        for deck in workspace.hyperdecks { deck.disconnect() }
    }
}
