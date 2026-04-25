# PiChat v1.0.8

## Highlights

- Adds reliable paste support for Finder files and image files.
- Adds polished drag-and-drop attachments across the chat window.
- Improves attachment preview and input handling for mixed text, images, and files.

## Paste and attachments

- `Cmd+V` now supports files copied from Finder, including image files such as PNG, JPG, GIF, TIFF, WebP, and HEIC.
- Screenshots and copied image data continue to paste as image attachments.
- File URL pasteboard formats are normalized so Finder copy/paste works more consistently.
- Duplicate attachments are ignored to avoid repeated cards for the same file.
- MIME type detection now uses macOS Uniform Type Identifiers for better image/file classification.

## Drag and drop

- Drop images and files anywhere in the chat to attach them.
- Added a clear full-chat drop overlay with accepted attachment hints.
- Dropped images become visual attachment cards in the input area.
- Dropped non-image files are attached as file cards.

## UI polish

- Refined chat/input attachment flow with clearer feedback notifications.
- Preserves long pasted text behavior while prioritizing file/image attachments when present.

## Installation

Download `PiChat-macOS.dmg`, drag `PiChat.app` into `Applications`, and choose **Replace** if prompted.
