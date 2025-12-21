# Repository Guidelines
## Always make a plan before doing a change and the user should accepet on it .
- Always make a plan before doing a change and the user should accepet on it
## Project Structure & Module Organization
- Flutter app code lives in `lib/` (for example `lib/app/`, `lib/features/`, `lib/models/`, `lib/api/`, `lib/data/`).
- Assets are in `assets/` and `lib/logo.png`, with entries in `pubspec.yaml`.
- Flutter tests live in `test/`; API tests live in `server/test/`.
- Backend API code is in `server/` (Express + MongoDB).
- Platform shells are in `android/`, `ios/`, `web/`, `macos/`, `linux/`, and `windows/`.
- `madina-ecommerce/` is a separate React/Node workspace with its own `package.json`.

## Build, Test, and Development Commands
- `flutter pub get` installs Flutter dependencies.
- `flutter run` runs the app on a device or emulator.
- `flutter build <platform>` builds a release (`apk`, `ios`, `web`, etc.).
- `flutter analyze` runs Dart/Flutter lints.
- `flutter test` runs Flutter tests in `test/`.
- `cd server && npm install` installs API dependencies.
- `cd server && npm run dev` starts the API with nodemon.
- `cd server && npm start` starts the API once with Node.
- `cd server && npm test` runs the Node test runner.
- `cd server && npm run download:images` / `npm run export:image-manifests` manage image assets.

## Coding Style & Naming Conventions
- Dart follows `flutter_lints` in `analysis_options.yaml`; format with `dart format .`.
- Use 2-space indentation, `lower_snake_case` for Dart files, `UpperCamelCase` for types, and `lowerCamelCase` for members.
- Server code follows existing JS style: 2-space indentation, double quotes, `camelCase` names.

## Testing Guidelines
- Flutter tests use `flutter_test` and live in `test/` with `*_test.dart` names.
- API tests use Node’s built-in runner with `*.test.js` in `server/test/`.
- No explicit coverage threshold is defined; add tests for new behavior and bug fixes.

## Commit & Pull Request Guidelines
- Commit history uses short, informal subjects (no conventional-commit scheme); keep messages concise and imperative.
- PRs should include a brief summary, testing notes, and screenshots for UI changes; link issues when applicable.

## Configuration & Environment
- Flutter API base URL is defined in `lib/config.dart` and can be overridden with `--dart-define=API_BASE=...`.
- Server configuration lives in `server/.env`; avoid committing secrets and document any new env vars in PRs.
