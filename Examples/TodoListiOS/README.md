# TodoListiOS Example

SwiftUITap demo app for iOS simulator.

## Prerequisites

- Start the relay server: `swiftui-tap server --port 9876`
- Boot a simulator: `xcrun simctl boot "iPhone 17 Pro"` (or use one already booted)

## Build

```bash
cd Examples/TodoListiOS

xcodebuild \
  -scheme TodoListiOS \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  build
```

## Install & Launch

```bash
# Find the .app in DerivedData
APP=$(find ~/Library/Developer/Xcode/DerivedData/TodoListiOS-*/Build/Products/Debug-iphonesimulator/TodoListiOS.app -maxdepth 0 2>/dev/null | head -1)

xcrun simctl install booted "$APP"
xcrun simctl launch booted com.hayeah.TodoListiOS
```

You should see `[SwiftUITap] Polling http://localhost:9876` in the server output.

## Verify

```bash
# Health check
curl localhost:9876/health

# Screenshot
swiftui-tap view screenshot -o screenshot.png

# View tree
swiftui-tap view tree

# State
swiftui-tap state get .
swiftui-tap state call addTodo title="Buy milk"
```

## App Structure

```
TodoListiOS/
├── Package.swift
└── TodoListiOS/
    ├── TodoListiOSApp.swift      # App entry, .tapInspectable() + SwiftUITap.poll()
    ├── State/
    │   ├── AppState.swift        # Root state with @SwiftUITap macro
    │   └── TodoItem.swift        # Todo model with @SwiftUITap macro
    └── Views/
        └── ContentView.swift     # UI with .tapID() tags
```

## Notes

- The app is a pure SPM executable — no `.xcodeproj`. Xcode treats the `Package.swift` as a workspace when using `xcodebuild -scheme`.
- `swift build` won't work for iOS targets — use `xcodebuild` with a simulator destination.
- The `AGENTSDK_URL` env var overrides the default server URL (`http://localhost:9876`).
