# Dumpling Not Dumpling — Design Spec

A Silicon Valley "Hot Dog Not Hot Dog" inspired app that classifies dumplings using on-device ML. Built with SwiftUI, targeting iPhone, iPad, Apple Watch, and macOS.

## Design System

- **Typography:** Inter (200 ultralight for display, 400/500 for body), IBM Plex Mono (500 for data/confidence)
- **Design framework:** IBM Carbon design tokens (8px grid, 48px min tap targets, Carbon color palette)
- **Materials:** Liquid glass — translucent backgrounds with `backdrop-filter: blur()` / SwiftUI `.ultraThinMaterial`
- **Light-first:** White/light gray backgrounds, dark text, color-coded accents
- **HCI constraints:** 48px min tap targets, primary actions in thumb zone (bottom 1/3), no overlapping elements, Gestalt proximity grouping, Fitt's law sizing

### Color System (Carbon tokens)

| Role | Color | Usage |
|------|-------|-------|
| Success (Dumpling) | `#198038` | Accent line, confidence text, share button |
| Error (Not Dumpling) | `#DA1E28` | Accent line, confidence text |
| Info (Full Mode ID) | `#0043CE` | Accent line for type identification |
| Text Primary | `#161616` | Display text, headings |
| Text Secondary | `#525252` | Body text, button labels |
| Text Placeholder | `#A8A8A8` | Hint text, secondary data |
| Layer 01 | `#F4F4F4` | Backgrounds, card fills |
| Border Subtle | `#E0E0E0` | Borders, dividers |

## App Modes

### Party Mode (Default)
Binary classification: "dumpling." or "not dumpling."
- Display: Ultralight Inter 200, large text
- Accent line: Green (dumpling) or red (not dumpling), 32px wide, 3px tall
- Confidence: IBM Plex Mono, color-matched to accent
- Animations: Spring scale pulse on result text, smooth card reveal

### Full Mode
Multi-class identification of specific dumpling types.
- Primary label: Specific type name (e.g., "xiaolongbao.")
- Accent: Blue (Carbon info)
- Secondary matches: Glass pills showing runner-up types with confidence scores
- Same layout structure as Party Mode with additional data

## Architecture

### Single Xcode Project
One project with shared SwiftUI views and platform-specific adaptations via `#if os()`.

### CoreML Model (`DumplingClassifier.mlmodel`)
- Created with Apple CreateML (Image Classification template)
- Transfer learning on Apple's base vision model
- Multi-class labels: `gyoza`, `xiaolongbao`, `pierogi`, `empanada`, `momo`, `ravioli`, `wonton`, `samosa`, `not_dumpling`
- Party Mode maps all dumpling classes → "dumpling."
- Target size: <10MB
- Training data: ~200-500 images per class from Open Images Dataset V7 (CC BY 4.0) and curated web sources

### Services

**CameraService.swift**
- Manages `AVCaptureSession` for live camera feed
- Platform-aware: iPhone/iPad get full camera, macOS gets camera + drop zone, Watch gets photo picker only
- Provides `CMSampleBuffer` frames for live classification
- Handles camera permissions

**ClassificationService.swift**
- Wraps `VNCoreMLRequest` for single-image classification
- Handles continuous classification from `AVCaptureVideoDataOutput`
- Throttles live classification to ~5 fps for battery efficiency
- Returns `ClassificationResult` with label, confidence, and dumpling type

### Data Model

```swift
struct ClassificationResult {
    let label: String           // "dumpling" or "not_dumpling" or specific type
    let confidence: Float       // 0.0 - 1.0
    let isDumpling: Bool        // convenience
    let dumplingType: String?   // nil in party mode, specific type in full mode
    let secondaryMatches: [(label: String, confidence: Float)]  // for full mode
}

enum AppMode {
    case party  // binary
    case full   // multi-class identification
}
```

## Platform UI

### iPhone (Primary)
- Camera viewport: Rounded corners, corner bracket indicators, full-width with 16px margins
- Mode toggle: Carbon segmented control below camera
- Controls: Bottom 1/3 thumb zone — photo library (48px), capture button (76px, center), LIVE toggle (48px)
- Result: Accent line → display text → monospace confidence → glass action buttons
- Animations: Spring card reveal, scale pulse on classification

### iPad
- Side-by-side split layout: Image/camera on left, results on right
- Same design language, adapted for larger canvas
- Both portrait and landscape support

### Apple Watch
- Dark background (watchOS standard)
- Home: "dumpling?" prompt, "Choose Photo" glass button, compact mode toggle
- Result: Accent line, ultralight text, abbreviated confidence (just the number)
- Haptic feedback: Success haptic for dumpling, failure for not
- CoreML model runs on-Watch (no WatchConnectivity delegation needed given <10MB model size)

### macOS
- Native window with traffic light controls
- Toolbar: App title center, segmented control for mode on right
- Content: Split pane — drag-and-drop zone (+ camera option) on left, results on right
- Supports drag-and-drop image files
- Native macOS via SwiftUI (no Catalyst)

## Input Methods

1. **Capture:** Tap shutter button to photograph and classify (iPhone, iPad, Mac)
2. **Photo Library:** Pick existing photo via `PHPickerViewController` (all platforms)
3. **Continuous Live:** Toggle LIVE mode for real-time classification on camera feed at ~5fps (iPhone, iPad)
4. **Drag and Drop:** Drop image files onto the window (macOS only)

## Share

Share uses SwiftUI `ShareLink` (iOS 16+) / `NSSharingServicePicker` (macOS). Shared content:
- The classified image
- Text overlay: "dumpling." or "not dumpling." with confidence
- App attribution watermark (optional, subtle)
- Available on iPhone, iPad, and macOS result screens (not Watch)

## Animations

- **Result reveal:** `.spring(response: 0.5, dampingFraction: 0.8)` slide-up card
- **Classification text:** Scale pulse from 0.9 → 1.0 with spring
- **Mode switch:** `.crossDissolve` transition
- **Live confidence:** Fluid bar/text updates with `.easeInOut(duration: 0.2)`
- **Watch:** WKInterfaceDevice haptic on result

## File Structure

```
DumplingNotDumpling/
├── DumplingNotDumpling/
│   ├── App/
│   │   ├── DumplingApp.swift
│   │   └── ContentView.swift
│   ├── Services/
│   │   ├── CameraService.swift
│   │   └── ClassificationService.swift
│   ├── Views/
│   │   ├── CameraView.swift
│   │   ├── ResultView.swift
│   │   ├── FullModeResultView.swift
│   │   └── Components/
│   │       ├── GlassButton.swift
│   │       ├── ModeToggle.swift
│   │       └── ConfidenceLabel.swift
│   ├── Models/
│   │   ├── ClassificationResult.swift
│   │   └── DumplingClassifier.mlmodel
│   └── Resources/
│       ├── Inter-ExtraLight.ttf    (weight 200, for display text)
│       ├── Inter-Regular.ttf       (weight 400)
│       ├── Inter-Medium.ttf        (weight 500)
│       ├── IBMPlexMono-Medium.ttf  (weight 500, for data)
│       └── Assets.xcassets
├── DumplingWatch/
│   ├── WatchApp.swift
│   ├── WatchContentView.swift
│   └── WatchResultView.swift
└── DumplingNotDumpling.xcodeproj
```

## Verification

1. **Build:** `xcodebuild -scheme DumplingNotDumpling -destination 'platform=iOS Simulator,name=iPhone 16'`
2. **Camera:** Test on physical device (camera unavailable in simulator)
3. **Photo Library:** Test classification with known dumpling and non-dumpling images in simulator
4. **Live Mode:** Test continuous classification on physical device, verify ~5fps throttle and battery impact
5. **Watch:** Test in Watch simulator with photo picker flow
6. **macOS:** Test drag-and-drop, camera access, window resizing
7. **Accessibility:** Verify VoiceOver reads classification results, all tap targets meet 48px minimum
