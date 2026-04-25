# PiChat v1.0.7

## Highlights

- Adds PiBrowser browser-control integration.
- Bundles the Pi browser tools extension with PiChat.
- Simplifies Browser settings to a single Browspi/PiBrowser ID field plus Connect/Disconnect actions.
- Installs the Chrome Native Messaging host and browser tools into PiChat application support.
- Improves browser-control UX with page highlighting and an agent cursor in the Chrome extension.

## Browser tools

Pi agents can now use real browser tools when PiBrowser is connected:

- `browser_open_tab`
- `browser_get_active_tab`
- `browser_get_page_context`
- `browser_click`
- `browser_type`
- `browser_press`
- `browser_scroll`
- `browser_screenshot`
- `browser_wait`

## Fixes

- Browser notifications now auto-dismiss through the normal PiChat notification flow.
- Browser control is enabled by default and no longer requires a visible toggle.
- Browser pairing no longer requires users to manually copy a separate pairing token.
