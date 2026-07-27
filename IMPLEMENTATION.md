# Implementation Notes

Running log of what was built for each ticket in `docs/tickets/`, why, and the
Flutter/Dart concept it introduces. Newest ticket at the bottom.

---

## T-001 — Project setup & first run

### What was built

- Scaffolded the Flutter project in place with `flutter create --org com.tally --project-name tally .`, which generated the standard layout: `lib/`, `pubspec.yaml`, and the native shells (`ios/`, `android/`, `macos/`, `web/`, `linux/`, `windows/` — Flutter generates all platform folders by default even though we only care about iOS for now).
- Replaced the generated counter-demo app in `lib/main.dart` with a minimal `TallyApp`.
- Updated `test/widget_test.dart` (which still referenced the deleted counter widget) to check for the "Tally" app bar and body text instead.
- Installed the toolchain that was missing on this machine: Flutter SDK (Homebrew), full Xcode (App Store, license + first-launch setup), and CocoaPods (needed later once we add native plugins like `sqflite`).

Key file: `lib/main.dart`

```dart
void main() {
  runApp(const TallyApp());
}

class TallyApp extends StatelessWidget {
  const TallyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tally',
      theme: ThemeData(
        colorSchemeSeed: Colors.deepPurple,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Tally')),
        body: const Center(child: Text('Tally')),
      ),
    );
  }
}
```

### Why structured this way

- Kept it as boring as the ticket asked: one file, one widget, no navigation, no state. Everything else in v1 builds on top of this, so there's nothing here to fight with later.
- `colorSchemeSeed` (rather than hand-picking a dozen colors) is Material 3's one-line way to derive a whole consistent palette from a single seed color — least code for "one consistent color" per the acceptance criteria.
- The generated `test/widget_test.dart` would have failed to compile once the counter widget was deleted, so it had to be updated in the same pass — otherwise `flutter analyze`/`flutter test` wouldn't have been clean.

### The concept: widget tree, and hot reload vs. hot restart

Coming from React: a **widget** is like a component, and the **widget tree** is like the component tree. Here it's:

```
TallyApp (StatelessWidget, root)
 └─ MaterialApp        // like a top-level <ThemeProvider> + router in React
     └─ Scaffold        // page chrome: gives you app bar + body slots
         ├─ AppBar (title: "Tally")
         └─ Center → Text("Tally")   // the actual page content
```

- `MaterialApp` is roughly your app's root provider — it sets up theming (`ThemeData`) and (later) routing.
- `Scaffold` is a layout convention for "one screen" — app bar up top, body below, plus optional slots we're not using yet (drawer, floating action button, bottom nav).
- `TallyApp` is a `StatelessWidget`: its `build()` output depends only on its constructor inputs (here, none) — the Dart equivalent of a pure function component. It has no internal state, unlike `StatefulWidget` (which we'll meet once screens need to hold data, e.g. text field input).

**Hot reload vs. hot restart** — the loop you tried:
- **Hot reload** (press `r` in the `flutter run` terminal, or the lightning-bolt icon in an IDE) injects the new code into the *already running* app and re-runs `build()`. Widget state is preserved — if you had a counter mid-count, it stays. This is why Flutter iteration feels so fast: it's closer to CSS/webpack hot-module-replacement than a full page refresh.
- **Hot restart** (`R`) tears down the whole app and starts fresh from `main()` — state resets, like a real reload of a React app (losing `useState`). Needed when reload can't apply the change (e.g. changing `main()` itself, or global/static initialization).

### Verified

- `flutter run` targeting the iPhone 17 Pro simulator — no build errors, screen shows the "Tally" app bar and centered body text (screenshot confirmed).
- `flutter analyze` → No issues found.
- `flutter test` → 1 passed.
- Hot reload confirmed manually: edited the body text, pressed `r`, simulator updated instantly.

### Environment notes (not code, but worth recording)

This machine had no Flutter SDK, no Android Studio, and only Xcode Command Line Tools (not full Xcode) installed. Since the founder's target device is an iPhone, we installed:
- Flutter via `brew install --cask flutter`
- Full Xcode via the App Store (Command Line Tools alone can't build/sign iOS apps)
- CocoaPods via `brew install cocoapods` (not needed by T-001's code, but required once we add plugins with native iOS code — better to get it out of the way now)

Android toolchain was left unconfigured since the founder's primary target is iPhone; `flutter doctor` still flags it, which is expected and fine.