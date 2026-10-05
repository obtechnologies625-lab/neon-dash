# Neon Dash

<p align="center">
  <a href="https://obtechnologies625-lab.github.io/neon-dash/">
    <img src="https://img.shields.io/badge/Play_Now-6bf5f0?style=for-the-badge&logo=godot-engine&logoColor=150e33" alt="Play Now">
  </a>
</p>

An endless runner built with **Godot 4.7** and **GDScript**, exported to run in a web browser.

You auto-run to the right. Jump the spikes, slide under the bars, scoop up coins, and try to beat your high score while the speed keeps climbing.

## How to Play

Click the **Play Now** badge above or go to:  
**https://obtechnologies625-lab.github.io/neon-dash/**

No download needed — it runs directly in your browser.

## Controls

| Action | Keys |
| --- | --- |
| Jump / double jump | `Space`, `W`, `Up`, `Enter`, or left-click / tap |
| Slide | `S`, `Down`, `Ctrl`, `Shift` |
| Pause | `Esc` or `P` |
| Restart | `R` |
| Settings | `O` (title screen, game-over card, or while paused) |

## Tips

- **Coyote time** and **jump buffering** — a jump pressed just before landing still fires, which makes the controls feel fair.
- **Variable jump height** — release early for a short hop, hold for height.
- **Sliding swaps the hitbox** — the standing collider is disabled and a short, wide one takes its place.
- **The difficulty ramps** from 340 to 820 px/s, with gaps tightening and new hazards unlocking over the first 35 seconds: spikes, double spikes, pillars, low bars, drones, then **gates** (26s) and **lasers** (34s). A laser charges with a dotted telegraph before its beam fires; slide under it.
- **Sound** is synthesised at startup, so there are no audio files either.
- **Settings** (`O`): difficulty (Easy / Normal / Hard), screen shake, particles, FPS counter, master and effects volume, and a confirm-to-erase best score. They are saved separately from your high score.

## High score storage

`high_score.gd` writes to `user://neon_dash_save.cfg`. On desktop that is a file in your Godot user data folder; in the browser build it maps to IndexedDB, so the score survives a page reload.

---

## Made by OB TECHNOLOGIES

OB TECHNOLOGIES is the creator of Neon Dash.  
For more projects and updates, visit: https://github.com/obtechnologies625-lab
