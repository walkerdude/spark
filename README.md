# Spark — Interest-Based Connections via NFC + Maps (iOS)

A Swift/SwiftUI iOS app that lets people connect based on **shared interests**. Users store interests, tap phones to **exchange profiles via NFC**, and optionally pin the **location** where they met on a map. Includes a lightweight account flow, profile/interest management, connection tracking, and a map view of your network.

---
 
## ✨ Features

- **Account flow**: simple sign up / login with local persistence.
- **Interests engine**: Academic / Sports / Media categories (add/remove in-app).
- **NFC exchange**: Read/write **NDEF** payloads with shared interests (iPhone 7+).
- **“Where we met”**: Long-press to drop a pin and save GPS coordinates.
- **Selfie on connect**: Capture a quick photo when adding a connection.
- **Connections list + leaderboard**: Track who you’ve met and compare counts.
- **Map of connections**: See saved connections as **MapKit** annotations.
- **All SwiftUI UI**, with UIKit bridges where needed (NFC, Camera, Maps).

---

## 🧱 Architecture & Key Types

**Frameworks:** `SwiftUI`, `Combine`, `UIKit`, `CoreNFC`, `CoreLocation`, `MapKit`  
**State:** `ObservableObject` + `@Published` (MVVM-ish, singletons for managers)  
**Persistence:** `UserDefaults` with `Codable` models (per-user namespaced keys)  

```
Spark/
├─ Models/
│  ├─ InterestsModel.swift        // Codable; default categories + values
│  ├─ UserProfile.swift           // Codable + Identifiable; interests, connections
│  └─ Connection.swift            // Codable + Identifiable + Hashable
│                                  // custom encode/decode for CLLocationCoordinate2D
├─ Managers/
│  ├─ InterestsManager.swift      // ObservableObject; persists per user
│  └─ UserManager.swift           // ObservableObject; profiles, session, connections
├─ NFC/
│  ├─ NFCReaderViewController.swift        // NFCNDEFReaderSessionDelegate
│  └─ NFCReaderViewRepresentable.swift     // SwiftUI bridge (UIViewControllerRepresentable)
├─ UI/
│  ├─ SwiftUI views: SignUpLoginView, HomeView, MenuView, ...
│  ├─ InterestCategoryView / EditInterestsView / CategorySelectionView
│  ├─ ConnectionsView / LeaderboardView
│  ├─ ConnectionsMapView (Map + annotations)
│  ├─ ConnectionPromptView (sheet after NFC read)
│  ├─ ImagePicker (UIKit bridge)
│  └─ LocationPickerViewController (+ representable)
└─ App/
   └─ ContentView.swift           // root Nav + environment objects
```

### Data Models (high-level)
- `InterestsModel`: `{ academicInterests: [String], sportsInterests: [String], mediaInterests: [String] }`
- `UserProfile`: `username`, `password`, `bio`, `interests`, `[Connection]`
- `Connection`: `username`, `date`, `photo (Data?)`, `location (CLLocationCoordinate2D?)`

### NFC Payload Format (as written/read)
```
Username: <username>
Academic Interests: Math, Science
Sports Interests: Football, Basketball
Media Interests: Movies, Music
```

---

## 🚀 Getting Started

### Prerequisites
- **Xcode 15+**
- **iOS 15+** (SwiftUI + UIKit bridges; NFC requires iPhone 7 or later)
- A physical iPhone for **NFC** testing (simulator does not support NFC)

### Clone & Run
```bash
git clone https://github.com/<your-org>/spark-ios.git
cd spark-ios
open Spark.xcodeproj
# Select a real iOS device target, then Build & Run
```

> 💡 NFC read/write requires a physical device and the **“Near Field Communication Tag Reading”** capability enabled.

---

## 🔐 Permissions & Capabilities

Add the following to **Signing & Capabilities**:
- **Near Field Communication Tag Reading**

Add to **Info.plist**:
- `NFCReaderUsageDescription` = “Spark uses NFC to share interests with nearby users.”
- `NSCameraUsageDescription` = “Spark uses the camera to attach a selfie when connecting.”
- `NSLocationWhenInUseUsageDescription` = “Spark uses your location to pin where you met.”
- (Optional) `NSPhotoLibraryAddUsageDescription` if you later allow saving images

---

## 🧭 How It Works (Flow)

1. **Sign Up / Login** (`SignUpLoginView`)
2. **Profile Home** (`HomeView`)
   - View your bio + interest categories
   - Tap **NFC** to read/write interests with another device
3. **NFC** (`NFCReaderViewController`)
   - Starts `NFCNDEFReaderSession`
   - Reads or writes a structured, human-readable payload
   - On success: parse → `ConnectionPromptView`
4. **Connect Prompt**
   - Optionally **take a selfie** (`UIImagePickerController`)
   - **Pin location** via `LocationPickerViewController` (Map long-press)
   - Save connection to the current user (`UserManager.addConnection`)
5. **Browse**
   - **ConnectionsView**: list + inline location/photo preview
   - **LeaderboardView**: ranked by `connectionCount`
   - **ConnectionsMapView**: map annotations of pinned locations

---

## 🧪 Testing Tips

- **NFC**: validate both **read** and **write** paths (multiple tags, timeout, user cancel).
- **Models**: round-trip encode/decode of `Connection` (including location) via `Codable`.
- **Persistence**: ensure `UserDefaults` keys are namespaced by username and updated on edits.
- **Map**: verify long-press adds an annotation and passes coordinates through the representable.
- **Camera**: confirm image capture → Data conversion → UI preview in the connect prompt.

---

## 🔧 Configuration Notes

- **Per-user storage**: `InterestsManager` stores interests under `InterestsData_<username>`.
- **Profiles** list persisted under `UserProfiles` via `UserManager.saveProfiles()`.
- **Error states**: NFC errors (user cancel / timeout / unsupported tag) are surfaced with alerts.

---

## 📈 Roadmap

- [ ] Replace `UserDefaults` with **Cloud sync** (e.g., CloudKit or Firestore).  
- [ ] Add **nearby discovery** (Bluetooth / MultipeerConnectivity) to complement NFC.  
- [ ] Encrypted NFC payloads + **verifiable profiles**.  
- [ ] Rich chat + shared media gallery per connection.  
- [ ] App Clips / QR fallback when NFC unavailable.

---

## 🤝 Contributing

1. Fork and create a feature branch: `git checkout -b feat/short-title`
2. Commit with clear messages and small, focused changes
3. Open a PR with a concise description and screenshots if UI changes

**Code style:** Swift 5, SwiftUI first; UIKit bridges where necessary; keep managers testable.

---

## 📝 License

MIT License (add a `LICENSE` file to your repo if you don’t already have one).

---

## 📸 Screenshots (placeholders)

> Replace with real captures from your device:
```
/Screenshots/
  01-login.png
  02-home.png
  03-nfc-read.png
  04-connection-prompt.png
  05-map-pin.png
  06-connections-list.png
  07-leaderboard.png
```

---

## 📚 Appendix: Notable Implementation Details

- **Custom Codable for Coordinates**  
  `Connection` manually encodes/decodes `CLLocationCoordinate2D` as `latitude`/`longitude` to keep models `Codable`.

- **SwiftUI ↔ UIKit Bridges**  
  `NFCReaderViewControllerRepresentable`, `LocationPickerViewControllerRepresentable`, and `ImagePicker` expose UIKit controllers into SwiftUI.

- **Interest Editing UX**  
  `EditInterestsView` supports add/remove with immediate persistence; categories selected via `CategorySelectionView`.

- **Leaderboard**  
  Sorted by `connectionCount` derived property on `UserProfile`.

---

### Quick Start for Demoing NFC

1. Build to **two** physical iPhones with `Near Field Communication Tag Reading` enabled.  
2. On device A, go to **Menu → Update NFC Tag** to **write** your current interests.  
3. On device B, tap **NFC** button on **Home** and hold near device A.  
4. Accept the connect prompt → take selfie (optional) → pin location (optional) → **Connect**.  
5. Check **Connections** list and **Map** to verify new entry.
