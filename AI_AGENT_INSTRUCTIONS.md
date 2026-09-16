# AI AGENT INSTRUCTIONS — PlayX Video Player (Flutter → Android APK)

You are being given a complete Flutter project. Your job is to build it into an
installable Android APK and give the resulting `.apk` file back to the user.

## Project type
- Framework: Flutter (Dart)
- Target: Android APK (release build)
- The `android/` platform folder is intentionally NOT included. It must be
  generated fresh before building.

## Folder structure provided
```
playx_video_player/
├── pubspec.yaml              # dependencies
├── lib/
│   ├── main.dart             # app entry point, dark theme default
│   ├── models/video_file.dart
│   ├── services/video_scanner.dart   # scans device storage for videos
│   └── screens/
│       ├── home_screen.dart          # folder view
│       ├── folder_videos_screen.dart # video list + thumbnails
│       └── player_screen.dart        # player with gestures + PiP
├── scripts/patch_manifest.py # patches AndroidManifest after generation
└── .github/workflows/build-apk.yml   # reference CI steps (for GitHub Actions)
```

## Exact build steps to run, in order

1. Make sure Flutter SDK (stable channel, 3.24+) and Java 17 are available.
2. From inside the `playx_video_player/` directory, run:
   ```
   flutter create --platforms=android --org com.ankit.playx .
   ```
   This generates the `android/` folder (gradle files, MainActivity, a
   default AndroidManifest.xml) WITHOUT overwriting the existing `lib/` or
   `pubspec.yaml`.
3. Patch the generated manifest so storage permissions and Picture-in-Picture
   support are added:
   ```
   python3 scripts/patch_manifest.py
   ```
   (This script edits `android/app/src/main/AndroidManifest.xml` in place.)
4. Install dependencies:
   ```
   flutter pub get
   ```
5. Build the release APK:
   ```
   flutter build apk --release
   ```
6. The finished file will be at:
   ```
   build/app/outputs/flutter-apk/app-release.apk
   ```
   Return/deliver this exact file to the user as the installable APK.

## If a build error occurs
- Do not silently skip features. Try to fix the actual error (e.g. dependency
  version conflicts in `pubspec.yaml`, Gradle/Java version mismatches).
- Common fixable issues:
  - Package version conflicts → run `flutter pub upgrade --major-versions`
    and re-run `flutter pub get`.
  - Gradle/Java mismatch → ensure Java 17 is used (`android/gradle.properties`
    and Gradle plugin versions may need adjusting for very new/old Flutter
    versions).
  - `MANAGE_EXTERNAL_STORAGE` permission triggering a Play Store policy
    warning is expected and fine for a sideloaded personal APK — do not
    remove it, since the app needs it to scan all folders for videos.
- If you cannot resolve an error, report the exact error text back rather
  than silently removing features (gestures, PiP, folder scanning, dark mode
  are all required — do not delete code to make the build pass).

## App feature checklist (must all work in the final APK)
- [ ] Scans phone storage and groups videos by folder
- [ ] Left-side vertical swipe = screen brightness
- [ ] Right-side vertical swipe = volume
- [ ] Horizontal swipe (either side) = seek forward/backward
- [ ] Dark mode is the default theme
- [ ] Picture-in-Picture button works on the player screen
- [ ] Auto-rotation between portrait/landscape works during playback

## Output required
A single file: `app-release.apk`, ready to sideload onto an Android phone.
