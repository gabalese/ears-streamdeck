# Ears Mute for Stream Deck

A Stream Deck key that toggles [Ears](https://retina.studio/ears/)' InstaMute and shows whether your microphone is live or muted.

| Live | Muted |
|:---:|:---:|
| ![live](com.gabalese.ears.sdPlugin/imgs/key-live@2x.png) | ![muted](com.gabalese.ears.sdPlugin/imgs/key-muted@2x.png) |

## How it works

- **Toggle:** pressing the key sends Ears' InstaMute hotkey through System Events. The shortcut is read from Ears' preferences, so it follows whatever you've configured. (Raw synthetic key events are ignored by Ears, and changing the CoreAudio mute flag directly is reverted by Ears while it considers you muted.)
- **State:** the key watches the CoreAudio mute flag on the default input device, which is what Ears sets. It updates live when you mute via the hotkey, Ears' menu, `ears --mute`, or when you switch input devices in Ears.

## Requirements

- macOS 11+ on Apple Silicon
- Stream Deck 6.4+
- Ears with an **InstaMute shortcut set** and InstaMute in **Toggle** mode

## Install

1. Download `com.gabalese.ears.streamDeckPlugin` from the [latest release](../../releases/latest) and double-click it.
2. If macOS blocks the binary (it is not notarized), run:
   ```
   xattr -dr com.apple.quarantine ~/Library/Application\ Support/com.elgato.StreamDeck/Plugins/com.gabalese.ears.sdPlugin
   ```
   and restart Stream Deck.
3. Drag **Ears Mute → Toggle Mute** onto a key.
4. On first press, allow Stream Deck to control **System Events**, and grant **Accessibility** if asked (System Settings → Privacy & Security).

## Build from source

Requires the Xcode Command Line Tools.

```
./build.sh      # builds the binary and icons into com.gabalese.ears.sdPlugin
./install.sh    # symlinks the plugin into Stream Deck and restarts it
./package.sh    # creates release artifacts in dist/
```

## Troubleshooting

Every key event and state change is logged to `~/Library/Logs/ElgatoStreamDeck/ears-plugin-debug.log`.

A key showing red while Ears thinks you're live means the device itself was left muted outside Ears; press twice to resync.
