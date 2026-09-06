# Emoji Access

A more reachable emoji overlay for [Omarchy](https://omarchy.org/) Quattro.

The built-in picker is a glyph grid with substring search. This one keeps the same Super+Ctrl+E summon, then adds the things that make emojis actually findable:

- Search by **name and keyword**, ranked so `joy` lands on 😂 and `grin face` stays a grinning face
- Typing switches to a **named list** so you can read the label, not guess the glyph
- **Categories** down the left: Recent, Smileys, People, Nature, Food, Travel, Activities, Objects, Symbols, Flags
- A **preview** of the current emoji with its official name
- **Recents** remembered between summons
- Enter inserts into the focused app; Shift+Enter or Ctrl+C copies

Enabling this plugin replaces `omarchy.emojis`, so the stock hotkey and `omarchy menu emoji` keep working.

## Install

```sh
omarchy plugin add https://github.com/silvaio/emoji-access.git --enable
```

Or install this checkout:

```sh
omarchy plugin validate .
omarchy plugin add "$(pwd)" --enable --yes
```

`omarchy plugin add` clones the repo into `~/.config/omarchy/plugins/silvaio.emoji-access`. After local edits, commit them and run `omarchy plugin update silvaio.emoji-access`.

## Usage

| Key | Action |
|---|---|
| Type | Search by name or keyword |
| Esc | Clear the search, or close |
| Arrows | Move through the grid or list |
| Tab / Shift+Tab | Next / previous category |
| `[` `]` | Previous / next category |
| Enter | Insert into the focused window |
| Shift+Enter | Copy and close |
| Ctrl+C | Copy and stay open |

Click a category to browse. Click an emoji to insert it.

## Remove

```sh
omarchy plugin remove silvaio.emoji-access
```

That restores the built-in emoji overlay.

## Dataset

`emojis.json` is generated from Unicode `emoji-test.txt` (fully-qualified glyphs, no skin-tone variants) and merged with Omarchy's keyword list so aliases like `yes` still find 👍.

```sh
python3 scripts/build-emojis.py
```

## Tests

```sh
node --test tests/test-emoji-model.js
```

## License

MIT
