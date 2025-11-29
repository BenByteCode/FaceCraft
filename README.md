# 🧠 FaceCraft

**FaceCraft** is a SwiftUI-based iOS app that detects and traces human faces and eyes from a live camera stream using Apple's Vision framework. It is designed to evolve into a creative playground for facial transformations—such as applying fun filters, altering face/hair/eye colors, or replacing human faces with animated characters.

---

## ✨ Features
- 📸 Real-time face and eye detection using Vision and AVFoundation.
- 🧠 Modular Camera Face Detection Service.
- 🪞 Live camera preview with overlay annotations.
- ✅ SwiftUI + Combine architecture with reactive data binding.

---

## 🛠 Architecture

- `CameraFaceDetectionService`: A reusable service built on top of AVFoundation and Vision to detect faces and facial landmarks.
- `CameraPreviewViewModel`: Publishes the list of detected faces to the UI.
- `CameraPreviewView`: SwiftUI-based view that renders the live camera feed and overlays detected face boxes.

---

## 📦 Installation

1. Clone the repository:
```bash
   git clone https://github.com/BenByteCode/FaceCraft.git
   cd FaceCraft
```

2. Open FaceCraft.xcodeproj in Xcode (16.0+).
3. Make sure your app has the following privacy descriptions in Info.plist:
```xml
<key>NSCameraUsageDescription</key>
<string>FaceCraft needs access to the camera for face detection.</string>
```
4. Run on a real iOS device (face detection does not work on the simulator).

--- 

## 🚧 Roadmap

FaceCraft is under active development. Planned features include:
- 🎭 Face replacement with custom avatars or 3D masks.
- 🎨 Real-time filters (face color, hair dye, etc.).
- 👁️ Eye color changers and effects.
- 😄 Expression detection and emoji overlay.

--- 

## 👤 Author

Brendan Kim (brendankim91@gmail.com)
