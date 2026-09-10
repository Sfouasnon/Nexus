import AppKit
import SwiftUI
import Observation

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
    let atem: NexusBridge
    let demo: Bool
    var routers: [RouterSession] = []
    var selection = "atem-0"
    var atemPages = ["switcher", "switcher"]
    var settings = false
    var status = ["Offline", "Offline"]
    let customizations: CustomizationStore
    let salvos: SalvoStore

    init(demo: Bool) {
        self.demo = demo
        atem = NexusBridge(demo: demo)
        customizations = CustomizationStore()
        salvos = SalvoStore()
        let ids = UserDefaults.standard.stringArray(forKey: "nexus.routers") ?? ["primary"]
        routers = ids.enumerated().map { RouterSession(id: $0.element, number: $0.offset + 1,
            demo: demo, customizations: customizations, salvos: salvos) }
        atem.featureHandler = { [weak self] feature, session in
            guard let self else { return }
            self.selection = feature == "hyperdeck" ? "hyperdeck" : "atem-\(session)"
            if feature != "hyperdeck" { self.atemPages[Int(session)] = feature }
        }
        refresh()
    }
    func refresh() { status = [atem.status(0), atem.status(1)] }
    func addRouter() {
        let router = RouterSession(id: UUID().uuidString, number: routers.count + 1,
            demo: demo, customizations: customizations, salvos: salvos)
        routers.append(router)
        UserDefaults.standard.set(routers.map(\.id), forKey: "nexus.routers")
        selection = router.id
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
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    private static let brandLogo = Bundle.main.url(forResource: "Nexus-AppIcon", withExtension: "png")
        .flatMap { NSImage(contentsOf: $0) }
    private let pages = [("switcher", "Switcher"), ("audio", "Audio"), ("color", "Camera / Color"),
                         ("labels", "Labels"), ("media", "Media")]
    var body: some View {
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
                        hardwareTab("ATEM A", id: "atem-0", icon: "slider.horizontal.3", status: workspace.status[0])
                        hardwareTab("ATEM B", id: "atem-1", icon: "slider.horizontal.3", status: workspace.status[1])
                        ForEach(workspace.routers) { router in
                            hardwareTab(router.name, id: router.id, icon: "square.grid.3x3",
                                status: workspace.demo ? "Demo" : router.store.connectionState.label)
                        }
                        hardwareTab("HyperDecks", id: "hyperdeck", icon: "record.circle", status: "Via ATEM")
                    }
                }
                Button { workspace.addRouter() } label: {
                    Label("Add Videohub", systemImage: "plus")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .help("Add another independently connected Smart Videohub")
                .accessibilityLabel("Add Videohub")
                .accessibilityIdentifier("add-videohub-button")
                if workspace.demo { Text("DEMO").font(.caption.bold()).foregroundStyle(.orange) }
            }
            .padding(.horizontal, 20).padding(.vertical, 12)
            .background(Color(red: 0.055, green: 0.075, blue: 0.10))
            Divider()
            ZStack {
            VStack(spacing: 0) {
            if workspace.selection.hasPrefix("atem-") {
                let index = workspace.selection == "atem-0" ? 0 : 1
                HStack(spacing: 8) {
                    ForEach(pages, id: \.0) { page in
                        Button(page.1) { workspace.atemPages[index] = page.0 }
                            .buttonStyle(.bordered)
                            .tint(workspace.atemPages[index] == page.0 ? .cyan : .gray)
                    }
                    Spacer()
                    Text("ATEM \(index == 0 ? "A" : "B")").font(.caption.bold()).foregroundStyle(.secondary)
                }.padding(10)
                ATEMPanel(bridge: workspace.atem, feature: workspace.atemPages[index], session: index, window: window)
                    .id("atem-panel")
            } else if workspace.selection == "hyperdeck" {
                HStack {
                    Text("HyperDeck transport · managed through ATEM A or B")
                    Spacer()
                    Text("Standalone connections are not yet available").foregroundStyle(.secondary)
                }.font(.caption).padding(12)
                ATEMPanel(bridge: workspace.atem, feature: "hyperdeck", session: 0, window: window)
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
                        .opacity(workspace.selection == router.id ? 1 : 0)
                        .disabled(workspace.selection != router.id)
                        .allowsHitTesting(workspace.selection == router.id)
                        .accessibilityHidden(workspace.selection != router.id)
                    }
                }
                .opacity(workspace.routers.contains(where: { $0.id == workspace.selection }) ? 1 : 0)
                .allowsHitTesting(workspace.routers.contains(where: { $0.id == workspace.selection }))
                .accessibilityHidden(!workspace.routers.contains(where: { $0.id == workspace.selection }))
            }
        }
        .frame(minWidth: 1180, minHeight: 800)
        .background(Color(red: 0.035, green: 0.05, blue: 0.07))
        .preferredColorScheme(.dark)
        .onReceive(timer) { _ in workspace.refresh() }
        .sheet(isPresented: $workspace.settings) {
            if let router = workspace.routers.first(where: { $0.id == workspace.selection }) {
                VStack {
                    HStack { Text("\(router.name) Settings").font(.headline); Spacer(); Button("Done") { workspace.settings = false } }.padding()
                    SettingsView(store: router.store, bridge: router.bridge)
                }.frame(minWidth: 720, minHeight: 550).preferredColorScheme(.dark)
            }
        }
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
        if let iconURL = Bundle.main.url(forResource: "Nexus", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        }
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
        if let i = args.firstIndex(of: "--preview-tab"), args.indices.contains(i + 1) { workspace.selection = args[i + 1] }
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
        workspace.atem.shutdown()
        for router in workspace.routers { router.store.disconnect() }
    }
}
