# Repository Guidelines

## Project Structure & Module Organization

This repository is the active Flutter project for RecordMyTime. App source lives in `lib/`: `main.dart` wires the adaptive navigation, `screens/` contains UI pages, `models/` contains data objects, `utils/` contains persistence, sync, OCR, AI, and service logic, `theme/` defines Material styling, and `widgets/` holds shared UI components. Platform code is under `android/`, `macos/`, and `windows/`. Assets are in `assets/`, including `assets/app_icon.png` and bundled fonts. Tests live in `test/`; currently only a basic widget test is present.

Do not modify the sibling legacy `recordmytime/` project unless explicitly asked.

## Build, Test, and Development Commands

Run commands from the project root:

```bash
flutter pub get          # install dependencies
flutter analyze          # static analysis and lint checks
flutter test             # run Flutter tests
flutter run -d android   # run on Android device/emulator
flutter run -d macos     # run macOS build locally
flutter build apk        # produce Android release APK
flutter build macos      # produce macOS app
```

Use `flutter pub outdated` before dependency upgrades. Android launcher icons use `flutter_launcher_icons` with `assets/app_icon.png`.

## Coding Style & Naming Conventions

Use Dart style with two-space indentation and run `dart format` before committing. Follow Flutter conventions: `PascalCase` for widgets/classes, `camelCase` for fields and methods, and `snake_case.dart` for filenames. Prefer existing patterns: plain `StatefulWidget` + `setState`, service classes in `lib/utils/`, and shared UI through `lib/widgets/app_components.dart`. Keep UI text routed through `AppLocalizations` when user-facing.

## Testing Guidelines

There is no broad test suite yet, so every behavioral change should at least pass `flutter analyze` and targeted manual verification. Add widget tests in `test/` using `*_test.dart` names when changing reusable widgets, navigation, or user-visible state. For OCR, file import, sync, and platform behavior, verify on the relevant Android/macOS target.

## Commit & Pull Request Guidelines

Recent commits use concise Chinese summaries such as version updates, bug fixes, and feature additions. Keep commit messages short and action-oriented, for example `修复长图 OCR 换行问题` or `更新文件详情页菜单`. Pull requests should include a brief change summary, manual test results (`flutter analyze`, build command, device tested), screenshots for UI changes, and linked issues or reproduction notes when relevant.

## Security & Configuration Tips

PocketBase sync configuration is in service code; avoid committing secrets or private endpoints beyond existing project settings. Keep `pubspec.yaml` version and `lib/app_info.dart` display version in sync for releases. macOS network entitlements are required for sync and should not be removed.
