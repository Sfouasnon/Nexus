# Nexus

A native macOS working surface combining the ATEM CNTRL and Videohub CNTRL prototypes in one window. Requires macOS 14 or later and the Blackmagic ATEM Software Control runtime/Developer SDK installed at the original prototype's standard location.

## Use

Build with `./Tools/build.sh`, then open `build/Nexus.app`.

- **ATEM A / ATEM B:** independent switcher connections with live status in the top tabs. Enter the address and Connect on the Switcher page. Switching tabs keeps both sessions running. Audio, Camera / Color, Labels, and Media open within the same window.
- **Videohub:** the existing source → destination → TAKE workflow, routing, macros, discovery, customizations, and settings. Use **+** to add another independent router tab. Edit the tab name above its routing surface. Addresses, names, and tab inventory persist. New routers wait for an explicit Connect; automatic reconnect is available in Router Settings.
- **HyperDecks:** the existing ATEM-managed transport controls. Choose the managing ATEM A/B inside this tab. This version does not connect directly to standalone HyperDecks.
- **Demo:** run `build/Nexus.app/Contents/MacOS/Nexus --demo` to explore synthetic ATEM and Videohub hardware without transmitting hardware commands.

The shared window does not disconnect hardware when navigating away. Closing the last window quits the app and disconnects sessions. Camera control retains the original isolated helper process and starts only when explicitly requested.

## Scope

The current ATEM backend supports two switchers. Multiple Videohubs can be added. Standalone HyperDeck connections and arbitrary additional ATEMs are follow-up integrations. All existing limitations of the prototypes' hardware implementations still apply. Live hardware must be used to validate actual routing, switching, recording, and device-specific capabilities.

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

Verified on this Mac: app build, code signature and bundle metadata; native demo rendering for ATEM and Videohub; independent ATEM A/B Program state across tab switches; per-ATEM page selection; embedded Audio, Camera / Color, Labels, Media and HyperDeck panels; Videohub search retained across hardware switches; Router Settings sheet. No physical hardware commands were tested.
