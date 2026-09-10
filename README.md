# Dank Display Mirror

A DankMaterialShell 1.6+ Control Center widget for `wl-mirror`.

It adds an Apple-style screen mirroring router to the Control Center. Choose a
source in the left column and a destination in the right column, then add a
fullscreen mirror.

## Requirements

- DankMaterialShell 1.6 or newer
- `wl-mirror`
- A compositor that supports one of `wl-mirror`'s capture protocols

## Install

```bash
mkdir -p ~/.config/DankMaterialShell/plugins
cp -r "$(pwd)" ~/.config/DankMaterialShell/plugins/DankDisplayMirror
```

Then open **Settings → Plugins**, scan for plugins, enable **Screen Mirroring**,
and add it to the Control Center layout.

## Behavior

- Run multiple mirrors at the same time.
- Use the always-visible **From → To** columns without focus-stealing dropdowns.
- One source can feed several destination displays.
- Each destination can host one fullscreen mirror.
- Stop routes independently from the active mirror list.
- The compact tile starts the last-used available route, or stops all routes.
- The detail panel lists enabled displays reported by `dms randr --json`.
- Each destination display shows its selected source fullscreen.
- Mirroring stays active when the Control Center closes because a plugin daemon
  owns the `wl-mirror` process.
- Closing the mirror window updates the tile back to its idle state.
- Pointer visibility and scaling are configurable in the plugin settings.

## Development

Reload after changes:

```bash
dms ipc call plugins reload dankDisplayMirror
```

For shell errors, run DMS from a terminal:

```bash
dms kill
dms run
```
