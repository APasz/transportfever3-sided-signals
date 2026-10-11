# Sided Signals

Adds reusable construction parameters to Transport Fever 3 railway signals:

- default, left, or right model placement;
- −5–20 m of signed lateral offset in 0.5 m steps;
- −20–50 m of signed track offset;
- optional advanced adjustments, shown with an in-game toolbar toggle;
- −7.5–7.5 m of vertical adjustment in 0.25 m steps when enabled;
- −30–30° of yaw adjustment in 1° steps when enabled;
- −15–15° of pitch and roll adjustment in 1° steps when enabled;
- default, signal, or waypoint function;
- Default, Off, or On whistle behaviour for passing trains; and
- the game's standard one-way option for signals.

The default values preserve each signal's original appearance and behaviour. Geometric adjustments and the advanced-adjustments toggle added by Sided Signals appear in the placement toolbar; side, function, whistle, and one-way remain in the construction menu. Existing side, track offset, height offset, yaw, pitch, roll, waypoint, whistle, and one-way controls from other mods are retained rather than duplicated. Advanced adjustments are disabled by default. The mod setting controls their initial visibility when a game loads; the toolbar toggle can show or hide them for the current session. A separate mod setting selects the default track offset for newly placed signals from −20 to 50 m; it defaults to 0 m.

The compatibility-override mod setting is also disabled by default. When enabled, Sided Signals adds its controls to every track-snapped edge object, including third-party constructions whose category and resource path are not recognized. It does not include ordinary assets because they do not provide the signal and edge-model data needed by the controls.

Whistle is independent of the selected function, so both signals and waypoints can trigger it. On uses the game's `horn` sound event, Off clears an authored sound event, and Default leaves the original value unchanged.

The construction controls and mod-browser metadata are localised for all 22 supported locales. The English text is used as the game's fallback if a locale is unavailable.

## Compatibility metadata

Signal authors can provide model-specific alignment corrections in a model's metadata:

```lua
metadata = {
    apasz_sided_signals = {
        version = 1,
        ignore = false,
        lateralCorrection = {
            left = 0.0,
            right = -0.5,
        },
    },
}
```

Corrections are measured in metres and follow the lateral-offset convention: positive values move the model farther from the track and negative values move it closer. Missing `left` or `right` values default to zero. Corrections apply only when Left or Right is selected; Default always preserves the model's authored placement. An author-provided `lateralCorrection` takes precedence over the mod's built-in correction for that model; metadata containing only `ignore` leaves built-in corrections intact.

Set `ignore = true` to opt out. On model metadata, this prevents every Sided Signals transformation whenever that model appears in a signal result. The controls can remain visible because the game defines construction parameters before the update script reveals which model it uses. To opt out a whole signal and omit the controls too, put the same metadata table on the signal construction instead. `ignore` must be a boolean; omitting it is equivalent to `false`.

## Development

The runtime Lua files in `content/` are generated from the typed Teal sources in `src/`:

```sh
tl --werror all check src/mod.script.tl src/sided_signals/*.tl
for source in src/mod.script.tl src/sided_signals/*.tl; do
    output="content/${source#src/}"
    tl gen -o "${output%.tl}.lua" "$source"
done
stylua content
lua tests/sided_signals_check.lua
python3 tests/localization_check.py
```

`mod.script.tl` is intentionally only the engine entry point. Parameter injection,
metadata validation, model-alignment capture, and runtime placement each live in a
focused module under `src/sided_signals/`; first-party compatibility corrections are
kept separately in `model_overrides.tl`.
