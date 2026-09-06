# Emoji Access

A more reachable emoji overlay for [Omarchy](https://omarchy.org/) Quattro.

The built-in picker is a glyph grid centered on the screen. This one behaves like **Win+.**: a compact popup next to the pointer, then paste back into the window you were typing in.

- **Super+.** (and Super+Ctrl+E) summons it
- The popup sits **below the pointer**, so a tab-group rename or inline field stays visible
- Search by **name and keyword**, ranked so `joy` lands on 😂 and `grin face` stays a grinning face
- Typing switches to a **named list** so you can read the label
- **Categories** down the left: Recent, Smileys, People, Nature, Food, Travel, Activities, Objects, Symbols, Flags
- Enter inserts at the caret; Shift+Enter or Ctrl+C copies

Enabling this plugin replaces `omarchy.emojis`, so the stock hotkey and `omarchy menu emoji` keep working.

Add the Win+. binding in `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + PERIOD", "Emojis", "omarchy-shell shell toggle omarchy.emojis")
```

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
| Super+. | Open next to the pointer |
| Type | Search by name or keyword |
| Esc | Clear the search, or close |
| Arrows | Move through the grid or list |
| Tab / Shift+Tab | Next / previous category |
| `[` `]` | Previous / next category |
| Enter | Insert into the field you were editing |
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
node --test tests
```

## License

MIT
