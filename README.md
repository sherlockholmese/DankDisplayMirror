# Dank Display Mirror

A Dux Shell / DankMaterialShell 2.0+ Control Center widget for `wl-mirror`.

It adds a screen mirroring panel to the Control Center. Choose where the picture
comes from and where it goes, check how it will fit, then start a fullscreen
mirror.

## Requirements

- Dux Shell / DankMaterialShell 2.0 or newer
- `wl-mirror`
- A compositor that supports one of `wl-mirror`'s capture protocols

## Install

```bash
mkdir -p ~/.config/dms/plugins
cp -r "$(pwd)" ~/.config/dms/plugins/DankDisplayMirror
```

Then open **Settings → Plugins**, scan for plugins, enable **Screen Mirroring**,
and add it to the Control Center layout.

## Behavior

- Run multiple mirrors at the same time.
- Use the always-visible **From → To** columns without focus-stealing dropdowns.
  Picking the display already chosen on the other side swaps the two.
- Displays are named by model and drawn in their true proportions.
- The scaling preview shows where the picture lands before you start.
- Displays appear and disappear as they are connected, with no refresh needed.
- A mirror that crashes stays listed with **Try again** until it is dismissed.
- One source can feed several destination displays.
- Each destination can host one fullscreen mirror.
- Stop routes independently from the active mirror list.
- The compact tile starts the last-used available route, or stops all routes.
- The detail panel lists enabled displays reported by `dms randr --json`.
- Each destination display shows its selected source fullscreen.
- Mirroring stays active when the Control Center closes because a plugin daemon
  owns the `wl-mirror` process.
- Closing the mirror window updates the tile back to its idle state.
- Pointer visibility is set in the plugin settings, which also hold the default
  scaling.

## Development

Reload after changes:

```bash
dms ipc call plugins reload dankDisplayMirror
```

If a load failed, `reload` retries the cached failure. Rescan to load the files
on disk:

```bash
dms ipc call plugin-scan rescan dankDisplayMirror
```

For shell errors, run DMS from a terminal:

```bash
dms kill
dms run
```
