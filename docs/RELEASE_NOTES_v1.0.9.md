# PiChat v1.0.9

## Highlights

- Fixes a macOS launch crash that could happen on another Mac after installing the DMG.
- Packages SwiftPM-generated resources correctly inside `PiChat.app/Contents/Resources`.
- Makes the startup logo loader resilient when packaged resources are unavailable.

## Fixed

- The macOS app no longer crashes in `Bundle.module` while rendering the PiChat logo.
- Release builds now include `PiChat_PiChat.bundle` under the app resources directory.
- Logo images are loaded from safe runtime locations first, with fallback behavior instead of a startup assertion failure.

## Installation

Download `PiChat-macOS.dmg`, drag `PiChat.app` into `Applications`, and choose **Replace** if prompted.
