# Emoji Access

A more reachable emoji overlay for [Omarchy](https://omarchy.org/) Quattro.

The built-in picker is a glyph grid centered on the screen. This one behaves like **Win+.**: a compact popup next to the pointer, then paste back into the window you were typing in.

- **Super+.** (and Super+Ctrl+E) summons it
- The popup sits **below the pointer** and does **not steal keyboard focus**, so a Chromium tab rename stays in edit mode
- Click an emoji to insert it at the caret; click the search row if you want to type-filter (that does take focus)
- Search by **name and keyword**, ranked so `joy` lands on 😂 and `grin face` stays a grinning face
- **Categories** down the left: Recent, Smileys, People, Nature, Food, Travel, Activities, Objects, Symbols, Flags

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
| Super+. | Open next to the pointer (keys stay in the app) |
| Click an emoji | Insert at the caret |
| Click search | Type to filter (takes keyboard) |
| Esc | Clear the search, or close (after search is focused) |
| Arrows | Move through the grid or list |
| Tab / Shift+Tab | Next / previous category |
| Enter | Insert into the field you were editing |

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
