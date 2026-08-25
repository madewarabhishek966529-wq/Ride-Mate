
# RemoteEye 👁️📱

**RemoteEye** is a production-quality, 100% open-source & cloud-free Flutter application that mirrors one Android phone's screen to another Android phone in real time with optional remote touch control — **without requiring Firebase, AWS, or any third-party cloud platforms**.

---

## 🌟 Key Features

1. **100% Standalone & Serverless**: No Firebase, no backend cloud servers, no account registration.
2. **Embedded WebSocket Signaling**: The Host phone acts as its own embedded signaling server (`LocalSignalingService`) using Dart's native `HttpServer`.
3. **P2P Screen Mirroring**: Direct low-latency WebRTC video streaming between Android devices with optional STUN/TURN fallback.
4. **Instant QR Code & IP Pairing**: Pairing UX via Host IP address or instant QR code scanning (`qr_flutter` + `mobile_scanner`).
5. **Optional Remote Touch Control**: Viewers can tap, double-tap, long-press, and swipe on the mirrored screen, plus trigger Android navigation actions (Back, Home, Recent Apps).
6. **No Root Required**: Touch control is executed natively on the host device using Android's `AccessibilityService` (`dispatchGesture`).
7. **Security First**: Remote touch control is **OFF by default** and requires explicit Host consent.

---

## 🏗️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── constants/        # RtcConfig (STUN/TURN), AppConstants
│   ├── network/          # LocalSignalingService (Embedded WebSocket Server & Client)
│   ├── theme/            # AppTheme (Futuristic cyan tech theme)
│   ├── utils/            # CodeGenerator, Logger
│   └── widgets/          # BrandLogo, StatusBadge
└── features/
    ├── accessibility/    # Native MethodChannel to Kotlin AccessibilityService
    ├── settings/         # SharedPreferences settings & STUN/TURN config UI
    ├── host/             # MediaProjection screen capture & WebRTC Host repository
    ├── viewer/           # RTCVideoRenderer, QR scanner, & DataChannel touch relay
    └── home/             # Main dashboard menu
```

* **State Management**: [Riverpod](https://pub.dev/packages/flutter_riverpod)
* **Navigation**: [GoRouter](https://pub.dev/packages/go_router)
* **WebRTC**: [flutter_webrtc](https://pub.dev/packages/flutter_webrtc)
* **Signaling**: Embedded WebSocket Server (`dart:io` `HttpServer` + `WebSocketTransformer`)

---

## 🌐 How Standalone Signaling Works

1. **Host Mode**: When the Host taps **Share My Screen**, RemoteEye starts a lightweight local WebSocket server on port `8080` (e.g. `ws://192.168.1.42:8080`).
2. **Pairing**: The Host displays its local IP address and a QR code containing `remoteeye://join/192.168.1.42:8080`.
3. **Viewer Connects**: The Viewer scans the QR code or types the Host IP. The Viewer establishes a direct WebSocket link to exchange WebRTC SDP Offer/Answer and ICE candidates.
4. **Auto Teardown**: Once the WebRTC peer connection status reaches `connected`, the embedded WebSocket server automatically shuts down!

---

## 📲 How to Test Across Two Physical Android Devices

### Host Device Setup (Phone A)
1. Open RemoteEye on Phone A and tap **Share My Screen**.
2. Grant Android's **Screen Capture (MediaProjection)** consent prompt.
3. Phone A will display its **Host IP Address** and **QR Code**.
4. *(Optional for Remote Control)*: Toggle **Allow Remote Control** ON. Enable the **RemoteEye Gesture Controller** under Android Accessibility Settings.

### Viewer Device Setup (Phone B)
1. Open RemoteEye on Phone B and tap **View Another Screen**.
2. Either enter Phone A's Host IP address or tap **Scan Host QR Code** to scan Phone A's screen.
3. Tap **Connect to Host Screen**.

### Live Streaming & Touch Control
* Within 1–2 seconds, Phone A's screen appears live on Phone B with real-time latency stats (e.g. `30 ms`).
* Tap or swipe on Phone B's screen — touch events are transmitted over `RTCDataChannel` and executed live on Phone A!
* Use the bottom action bar on Phone B to trigger Android navigation actions (**Back**, **Home**, **Recent Apps**).

---

## 📄 License
This project is licensed under the MIT License.
