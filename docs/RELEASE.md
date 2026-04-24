# PiChat Release Guide

## 1) Pre-release checks

```bash
swift build -c release
./scripts/sanity-check.sh
```

## 2) Build distributable

```bash
./scripts/build-dmg.sh
```

Artifacts:
- `build/PiChat.app`
- `build/PiChat-macOS.dmg`

## 3) Prepare GitHub page

- Add screenshots to `docs/images/`:
  - `screenshot-chat.png`
  - `screenshot-settings.png`
  - `screenshot-right-panel.png`
- Reference them from `README.md`

## 4) Publish

```bash
git add .
git commit -m "chore(release): prepare public launch"
git tag v1.0.0
git push origin main --tags
```

Then create a GitHub Release and attach `build/PiChat-macOS.dmg`.
