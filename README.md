# Neon Dash

<p align="center">
  <a href="https://obtechnologies625-lab.github.io/neon-dash/">
    <img src="https://img.shields.io/badge/Play_Now-6bf5f0?style=for-the-badge&logo=godot-engine&logoColor=150e33" alt="Play Now">
  </a>
</p>

An endless runner built with **Godot 4.7** and **GDScript**, exported to run in a
web browser.

You auto-run to the right. Jump the spikes, slide under the bars, scoop up coins,
and try to beat your high score while the speed keeps climbing.

![controls](https://img.shields.io/badge/controls-Space%20jump%20%C2%B7%20S%20slide-6bf5f0)

## Play it

```powershell
.\serve.ps1
```

Then open <http://localhost:8000>.

> Use `serve.ps1` (or any server that sends `Cross-Origin-Opener-Policy` and
> `Cross-Origin-Embedder-Policy` headers). Opening `build/index.html` directly
> with `file://` will **not** work — browsers block WebAssembly there.
> `npx serve build` works too if it sets those headers.

## Controls

| Action | Keys |
| --- | --- |
| Jump / double jump | `Space`, `W`, `Up`, `Enter`, or left-click / tap |
| Slide | `S`, `Down`, `Ctrl`, `Shift` |
| Pause | `Esc` or `P` |
| Restart | `R` |
| Settings | `O` (title screen, game-over card, or while paused) |

## How it plays

- **Coyote time** and **jump buffering** — a jump pressed just before landing still
  fires, which is what makes the controls feel fair.
- **Variable jump height** — release early for a short hop, hold for height.
- **Sliding swaps the hitbox** — the standing collider is disabled and a short,
  wide one takes its place.
- **The difficulty ramps** from 340 to 820 px/s, with gaps tightening and new
  hazards unlocking over the first 35 seconds: spikes, double spikes, pillars,
  low bars, drones, then **gates** (26s) and **lasers** (34s). A laser charges
  with a dotted telegraph before its beam fires; slide under it.
- **Sound** is synthesised at startup, so there are no audio files either.
- **Settings** (`O`): difficulty (Easy / Normal / Hard), screen shake, particles,
  FPS counter, master and effects volume, and a confirm-to-erase best score.
  They are saved separately from your high score.

## Project layout

```
project.godot        Project settings + autoloads
icon.svg             Window / favicon icon
export_presets.cfg   Web export preset
serve.ps1            Local server with the headers Godot's web build needs
build/               Exported web build (generated, not committed)
scenes/
  main.tscn          Root scene: world, ground, entities, camera, HUD
  player.tscn        CharacterBody2D with stand + slide colliders
  obstacle.tscn      Area2D hazard
  coin.tscn          Area2D collectible
scripts/
  main.gd            Game loop, spawning, difficulty, state machine
  player.gd          Movement, jumping, sliding, procedural character art
  obstacle.gd        Five hazard types, each with its own collision shape
  coin.gd            Spinning collectible with a collect tween
  world.gd           Parallax night-city backdrop
  ground.gd          Scrolling ground plane
  hud.gd             Score bar, title card, game-over card (built in code)
  gfx.gd             Shared procedural-art helpers (glow, neon lines, dust)
  controls.gd        Autoload: registers input actions
  high_score.gd      Autoload: saves best score / coins to user://
  settings.gd        Autoload `GameSettings`: preferences saved to user://
  audio.gd           Autoload `SoundFx`: synthesised sound effects
tests/
  run_tests.gd       Headless functional tests
tools/
  godot-editor/      Portable Godot 4.7.2 editor (not committed; see below)
  export.ps1         Rebuild build/index.html from the command line
```

**All art is drawn procedurally** in `_draw()` with polygons and shapes. There is
not a single image file in the project, which is why the exported game data is
only ~40 KB and the whole build is dominated by the engine's own `.wasm`.

## Working on it

The portable editor is too big for git, so after cloning, fetch it once with
`.\tools\download_godot.ps1` then `.\tools\setup_godot.ps1` (they download Godot
4.7.2 and its web export templates). Or use any Godot 4.7 install you already
have. Then open the project with the editor:

```powershell
.\tools\godot-editor\Godot_v4.7.2-stable_win64.exe --path .
```

Then `F5` to run, `F6` for the current scene.

To rebuild the web version after changing anything:

```powershell
.\tools\export.ps1
```

## Tests

The test suite drives the real game headlessly — title screen, a live run, the
difficulty ramp, a crash, and a restart:

```powershell
.\tools\godot-editor\Godot_v4.7.2-stable_win64.exe --headless --path . --import
.\tools\godot-editor\Godot_v4.7.2-stable_win64.exe --headless --path . res://tests/run_tests.tscn
```

It prints `[PASS]`/`[FAIL]` per assertion and exits non-zero on failure, so it
works in CI. The checks cover state transitions, scoring, spawning, the
unlock-timed hazard table, the laser and gate colliders, the settings menu, and
save/restart behaviour. (The count is now 47 checks.)

Note: run it as a **scene** (as above), not with `--script`. Autoload globals like
`HighScore` only resolve when a normal scene is loaded.

## High score storage

`high_score.gd` writes to `user://neon_dash_save.cfg`. On desktop that is a file
in your Godot user data folder; in the browser build it maps to IndexedDB, so
the score survives a page reload.