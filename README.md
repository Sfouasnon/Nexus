# Nexus

A native macOS working surface combining the ATEM CNTRL and Videohub CNTRL prototypes in one window. Requires macOS 14 or later and the Blackmagic ATEM Software Control runtime/Developer SDK installed at the original prototype's standard location.

## Use

Build with `./Tools/build.sh`, then open `build/Nexus.app`.

- **ATEM:** add as many independent switcher tabs as needed. Each tab has its own address, connection, editable name, and Switcher, Audio, Camera / Color, Labels, Media, and ATEM-managed HyperDeck pages.
- **Videohub:** add as many independent router tabs as needed. Each keeps its own address, discovery, connection, settings, and editable name while retaining the existing source → destination → TAKE workflow, routing, macros, and customizations.
- **HyperDeck:** add standalone recorders by IP address. Nexus connects directly over Blackmagic's Ethernet protocol and provides live transport status, timecode, slot, speed, play, stop, record, and previous/next clip controls.
- **Add Hardware:** use the menu at the right of the hardware tabs to add an ATEM, Videohub, or standalone HyperDeck. The complete device inventory and names persist across app launches.
- **Demo:** run `build/Nexus.app/Contents/MacOS/Nexus --demo` to explore synthetic ATEM and Videohub hardware without transmitting hardware commands.

The shared window does not disconnect hardware when navigating away. Closing the last window quits the app and disconnects sessions. Camera control retains the original isolated helper process and starts only when explicitly requested.

## Scope

Nexus does not impose a fixed device count. Practical limits depend on the Mac, network, and attached hardware. All existing limitations of the prototypes' hardware implementations still apply. Live hardware must be used to validate actual routing, switching, recording, and device-specific capabilities.

Nexus stores its own preferences and router customization/salvo data; it does not automatically migrate existing prototype settings. Multiple router tabs share the customization and salvo stores keyed by router identity, preventing concurrent file writers from overwriting each other. If enabling Stream Deck control on several routers, use a unique control API port for each (new slots default to separate ports).

## Implementation

`Sources/ATEM` and `Sources/Videohub` are local source snapshots of the working prototypes. The original project folders are unchanged. `NexusBridge` hosts the existing AppKit panels and directs them to the actual Nexus window; `NexusApp.swift` owns long-lived sessions and the SwiftUI tab shell. No child control applications are launched.

The build produces a signed app for the current Mac architecture. It bundles the camera helper and uses the installed Blackmagic SDK dispatch implementation. This is a development build, not a notarized distribution.

## Development checks

Capture a no-hardware preview with:

```
build/Nexus.app/Contents/MacOS/Nexus --demo --capture-ui build/atem-preview.png
build/Nexus.app/Contents/MacOS/Nexus --demo --preview-tab primary --capture-ui build/videohub-preview.png
build/Nexus.app/Contents/MacOS/Nexus --demo --preview-tab hyperdeck --capture-ui build/hyperdeck-preview.png
```

These commands launch the native UI, capture it after initialization, then quit. They do not verify communication with physical hardware.

Verified on this Mac: app build, code signature and bundle metadata; native demo rendering; adding multiple ATEM, Videohub, and standalone HyperDeck tabs; independent ATEM state across tab switches; per-ATEM page selection; embedded Audio, Camera / Color, Labels, Media and ATEM-managed HyperDeck panels; Videohub search retained across hardware switches; Router Settings sheet; standalone HyperDeck controls and status rendering. No physical hardware commands were tested.
