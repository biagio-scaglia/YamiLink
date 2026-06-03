# YamiLink

*“A social layer that exists only when you are there.”*

**YamiLink** is an offline-first, proximity-based communication app designed for temporary physical spaces like conventions, campus grounds, LAN parties, transit systems, and emergency scenarios. It acts as an ephemeral social layer that surfaces automatically when peers are physically close and completely disappears without leaving a trace once they leave.

---

## 🌌 Product Positioning

* **Tagline:** A social layer that exists only when you are there.
* **Core Promise:** See who is around. Connect locally. Leave nothing behind.
* **Tone:** Calm, atmospheric, subtle sci-fi, privacy-first.
* **Scope (MVP v1):** 1-hop adjacency discovery, ephemeral identities, environment broadcasts, trust pairing verification, and system telemetry diagnostics.

---

## 🛠️ Key Features (MVP v1)

1. **Ephemeral Profile Generation:**
   * Instant setup with zero signup or servers.
   * Auto-generates cryptographic node IDs in memory.
   * Generates a unique, procedurally drawn vector geometric avatar (`YamiAvatar`) from name seeds.
2. **Nearby Proximity Radar:**
   * Animated pulsing radar interface scanning for active local beacons.
   * Proximity badges indicating distance classes: `IMMEDIATE` (0-3m), `NEAR` (3-10m), and `FAR` (10-30m).
3. **Local Room Chat (1-Hop Broadcast):**
   * Infrastructure-less multi-user chat room for local announcements.
   * Fades entries dynamically, automatically destroying message caches upon exit.
4. **Direct Encrypted Chat & Trust Pairing:**
   * Private point-to-point chats between adjacent peers.
   * Slide-up Bottom Sheets for pairing verification, using simulated mutual passcode handshakes.
5. **System Diagnostics Console:**
   * HUD gauges monitoring peers in range, packet exchange rate, and signal strength.
   * Live streaming of system events and background packet telemetry logs.
   * Mesh relay toggling capability.

---

## 📂 Architecture & Modularity

The codebase is organized modularly to isolate the interface from the transport layer:

```
lib/
├── models.dart              # Core domain models (Profile, Peer, Message, Session)
├── theme.dart               # Visual tokens, glassmorphism decorations, and neon colors
├── simulation_service.dart  # State engine simulating peer discovery and messaging
├── entry_screen.dart        # Onboarding profile setup
├── nearby_screen.dart       # Proximity scanner and trust pairing sheet
├── room_screen.dart         # Broadcast room environment chat
├── direct_chat_screen.dart  # 1-hop private secure chat
├── diagnostics_screen.dart  # Telemetry console dashboard and streaming logs
├── main.dart                # Main entry point and bottom tab shell
└── widgets/
    └── avatar.dart          # CustomPainter rendering procedural vector shapes
```

---

## 🚀 Getting Started

### Prerequisites

* Flutter SDK (compatible with Dart 3.x)
* Android Studio / Xcode / VS Code configured with emulator/device

### Installation

1. Clone this repository to your local workspace.
2. Fetch dependencies:
   ```bash
   flutter pub get
   ```
3. Run the linter and format code:
   ```bash
   dart format .
   flutter analyze
   ```
4. Run the widget tests:
   ```bash
   flutter test
   ```
5. Deploy to a device/emulator:
   ```bash
   flutter run
   ```

---

## 🔮 Future Roadmap

* **Phase 2 - Direct Transport:** Integrate iOS Multipeer Connectivity and Android Nearby Connections/Wi-Fi Direct sockets.
* **Phase 3 - Multi-Hop Mesh:** Implement Epidemic routing Protocols (store-and-forward packet buffers) across adjacent terminal nodes.
* **Phase 4 - Cryptographic Pair Handshakes:** QR-code exchanges and cryptographic Diffie-Hellman key exchanges over BLE.
