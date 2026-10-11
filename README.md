# Way Up - 2D Scroller & Level Editor

[![Godot Engine](https://img.shields.io/badge/Godot-4.x-478CBF?logo=godotengine&logoColor=white)](https://godotengine.org/)

A vertical rhythm-platformer and standalone level creation suite built with **Godot Engine 4**. Design, customize, and playtest complex vertical levels featuring dynamic color channels, interactive orbs, transform gizmos, online music streaming, and fast physics.

---

## 📑 Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
  - [Level Editor Suite](#level-editor-suite)
  - [Gameplay Mechanics](#gameplay-mechanics)
  - [Music & Audio Integration](#music--audio-integration)
  - [Performance & Optimization](#performance--optimization)
- [Controls & Hotkeys](#controls--hotkeys)
- [Project Architecture](#project-architecture)
- [Level Data Format](#level-data-format)
- [Getting Started](#getting-started)
- [Export & Platforms](#export--platforms)

---

## Overview

**Way Up** blends rhythm-based vertical navigation with an in-game level editor. Players navigate upwards using multiple movement modes while dodging obstacles and triggering interactive objects synced to music. Creators can build, texture, layer, and test levels directly in the engine using a desktop and mobile-friendly editor interface.

---

## Key Features

### Level Editor Suite

- **Grid Snapping & Dynamic Canvas**:
  - 64×64 pixel grid snapping for precise object placement.
  - Dynamically expanding vertical canvas with infinite vertical room bounds and customizable border walls.
  - Batch painting tool: Click and drag to continuously place objects across grid cells.
- **Transform Gizmo & Fine Adjustments**:
  - Interactive multi-handle gizmo supporting free scaling, axis-constrained X/Y scaling, rotation, horizontal skewing, and simulated vertical skewing.
  - Quick action toolbar: 30° incremental rotations, horizontal & vertical flipping, and small/medium nudge buttons.
- **Selection & Multi-Select**:
  - Box selection: Hold modifier (`Ctrl` on Windows / `Cmd` on macOS) and drag to select multiple objects.
  - Click-cycle selection: Seamlessly toggle focus through overlapping or stacked objects.
- **Layer & Z-Order Management**:
  - Multi-layer support (`current_layer` 0..N) with isolated layer visibility toggling.
  - Granular depth sorting: Z-Layers ranging from background `-5` (`B5`) to foreground `+5` (`T5`), plus fine-tuned Z-Order spinbox control.
- **Dynamic Color Channels & Triggers**:
  - 11 configurable object color channels (Channels 0–10) plus Background channel (`BG` / `-1`).
  - **Color Triggers**: In-level triggers that interpolate channel colors with custom fade durations and real-time visual connection lines in the editor.
- **Group ID System**:
  - Assign objects to numeric Group IDs for synchronized mass behaviors and trigger routing.
- **Undo / Redo & Clipboard**:
  - 100-step serialized action history stack (`UndoRedoManager`) supporting placement, deletion, batch movement, and transform edits.
  - Deep-copy clipboard manager (`ClipboardManager`) for copying and pasting selections with full metadata, rotation, scale, and skew intact.
- **Level Management**:
  - Integrated Level Browser (`user://Levels/`) with fast header/tail parsing (`get_level_name_fast`, `get_object_count_fast`) for instant list population without loading heavy JSON files.
  - Level Details view with RegEx-based in-place renaming and object counters.

### Gameplay Mechanics

- **Vertical Rhythm Action**:
  - Upward auto-scrolling with responsive camera tracking and boundary collision checking.
- **Dual Movement Modes**:
  - **Ship Mode**: Smooth horizontal acceleration and deceleration with banked rotational tilt (`A`/`D` or Arrow keys).
  - **Ball Mode**: Snapped 1.5-grid step jumps with rapid 90° angular spins and physics deceleration.
- **Interactive Objects & Hazards**:
  - **Obstacles**: Static blocks, spiked hazards, clear transparent hazards, rotating sawblades (`SpinningObject`), and meteors.
  - **Touch Orbs**: Interactive rings triggered upon contact.
  - **Move Orbs**: Directional boost rings that propel the player horizontally with squash-and-stretch tween animations.
- **Instant Playtesting**:
  - Switch instantly between editor and live playtest mode with one click (`TestButton`) without reloading scenes.

### Music & Audio Integration

- **Online Song Downloader (`MusicDownloader`)**:
  - **NoCopyrightSounds (NCS)**: Fetch tracks directly via song ID with automatic link extraction for both **Regular** and **Instrumental** versions.
  - **Newgrounds Audio**: Download Newgrounds audio submissions directly via Audio ID.
- **Streaming & Local Caching**:
  - In-memory decoding with `AudioStreamMP3` for zero-restart audio assignment.
  - Local disk cache (`user://songs/<id>.mp3`) for offline playback.
  - Editor preview player with unified Play / Stop playback controls.

### Performance & Optimization

- **Vertical Chunking System**:
  - Level geometry is partitioned into vertical chunks (`CHUNK_HEIGHT = 512.0` in editor, `256.0` in play scene).
  - Out-of-view chunks automatically set `process_mode = PROCESS_MODE_DISABLED` and hide visibility, keeping draw calls and physics calculations low even on massive levels.
- **Threaded Level Saving**:
  - Level serialization gathers data synchronously, then delegates disk I/O to a background Godot `Thread` to eliminate frame stutter when saving large levels.

---

## Controls & Hotkeys

### Editor Controls

| Action                        | macOS Shortcut                  | Windows / Linux Shortcut        |
| :---------------------------- | :------------------------------ | :------------------------------ |
| **Pan Canvas**                | Left Click + Drag (Empty Space) | Left Click + Drag (Empty Space) |
| **Zoom In / Out**             | Mouse Wheel / Scroll            | Mouse Wheel / Scroll            |
| **Place Object (Build Mode)** | Left Click / Drag               | Left Click / Drag               |
| **Select Object (Edit Mode)** | Left Click                      | Left Click                      |
| **Cycle Overlapping Objects** | Left Click Repeatedly           | Left Click Repeatedly           |
| **Box Multi-Select**          | `Cmd` + Left Drag               | `Ctrl` + Left Drag              |
| **Move Selected Objects**     | Left Click + Drag Object        | Left Click + Drag Object        |
| **Delete Selected**           | `Backspace` / Delete            | `Backspace` / Delete            |
| **Copy Selection**            | `Cmd` + `C`                     | `Ctrl` + `C`                    |
| **Paste Clipboard**           | `Cmd` + `V`                     | `Ctrl` + `V`                    |
| **Undo**                      | `Cmd` + `Z`                     | `Ctrl` + `Z`                    |
| **Redo**                      | `Cmd` + `Y`                     | `Ctrl` + `Y`                    |
| **Pause / Close Menus**       | `Escape`                        | `Escape`                        |

### Gameplay Controls

| Action                                     | Keybinding           |
| :----------------------------------------- | :------------------- |
| **Steer Left (Ship) / Jump Left (Ball)**   | `Left Arrow` or `A`  |
| **Steer Right (Ship) / Jump Right (Ball)** | `Right Arrow` or `D` |
| **Pause / Resume**                         | `Escape`             |

---

## Project Architecture

```
level-editor/
├── project.godot                  # Godot 4 configuration (Mobile renderer, inputs, viewport 1280x720)
├── export_presets.cfg             # Export settings (iOS / Mobile presets)
├── global.gd                      # Global autoload singleton (level path routing, active color channels)
├── editor_ui.gd                   # Editor CanvasLayer UI (tabs, item databases, song downloader UI)
├── camera_2d.gd                   # Editor panning & clamped scrolling camera
├── room_canvas.gd                 # Dynamic grid rendering, border walls, and viewport redraws
│
├── scenes/
│   ├── rooms/
│   │   ├── main_menu.tscn         # Title screen with level editor navigation and quit option
│   │   ├── level_browser.tscn     # User level browser, level creation, and selection
│   │   ├── level_details.tscn     # Level metadata view, object count, renaming, and launch
│   │   ├── editor_root.tscn       # Main level editor environment
│   │   └── play_scene.tscn        # Dedicated gameplay scene with camera tracking & death loop
│   ├── objects/
│   │   ├── obstacles/             # Hazard scenes (blocks 1-8, spikes, clear spikes, sawblades, meteors)
│   │   ├── orbs/                  # Touch Orb and Move Orb scenes
│   │   ├── triggers/              # Color Trigger scene
│   │   └── deco/                  # Background and foreground decorations (stars, glow, lines, squares)
│   ├── overlays/
│   │   ├── transform_gizmo.tscn   # Interactive transformation gizmo node with 6 drag handles
│   │   └── game_overlay.tscn      # In-game pause, victory, and retry UI
│   ├── player/
│   │   ├── player.tscn            # Player CharacterBody2D scene with ship and ball modes
│   │   └── player_camera.tscn     # Smooth lerping tracking camera with edge thresholds
│   └── background/
│       └── background.tscn        # Parallax scrolling background layer
│
├── scripts/
│   ├── editor/
│   │   ├── save_load_manager.gd   # Threaded JSON level saving, compact deserialization, song persistence
│   │   ├── undo_redo_manager.gd   # Command pattern undo/redo stack with state serialization
│   │   ├── clipboard_manager.gd   # Selection clipboard for duplicate & paste workflows
│   │   └── music_downloader.gd    # HTTP scrapers and downloaders for NCS and Newgrounds audio
│   ├── rooms/
│   │   ├── editor_root.gd         # Editor state machine, hotkey routing, and chunk manager
│   │   ├── play_scene.gd          # Level playback loop, player spawning, trigger event listeners
│   │   ├── level_browser.gd       # Directory listing for user://Levels/ with quick header inspection
│   │   ├── level_details.gd       # Level inspector with regex-based title editing
│   │   └── main_menu.gd           # Menu button signal handling
│   ├── player/
│   │   ├── base_player.gd         # Ship and Ball movement physics, collision handling, death animations
│   │   └── player_camera.gd       # Velocity-coupled vertical tracking camera with deadzones
│   ├── objects/
│   │   ├── obstacle.gd            # Base obstacle script with color channel tinting
│   │   ├── orb.gd                 # Base orb script with tween animations and player detection
│   │   ├── move_orb.gd            # Horizontal impulse orb script
│   │   ├── touch_orb.gd           # Contact-triggered orb script
│   │   ├── trigger.gd             # Base trigger class
│   │   ├── color_trigger.gd       # Real-time channel color tweener
│   │   ├── deco.gd                # Decorative sprite script with color channel integration
│   │   └── spinning_object.gd     # Constant rotation script (sawblades)
│   ├── overlays/
│   │   ├── transform_gizmo.gd     # Gizmo drag calculations (scale, rotate, shear, skew)
│   │   └── game_overlay.gd        # Pause & restart overlay controller
│   └── foreground/
│       └── borders.gd             # Boundary tracker script
│
├── resources/
│   ├── backgrounds/               # Tileable background textures (background 1-4)
│   ├── fonts/                     # Bungee-Regular TTF font
│   ├── icons/                     # UI action and transform gizmo icons
│   ├── lasers/                    # Laser and projectile sprite assets
│   ├── objects/                   # gamesheet.png and decosheet.png sprite atlases
│   ├── sounds/                    # SFX (lasers, zaps, shields, death sounds)
│   └── theme/                     # Godot UI theme configuration
```

---

## Level Data Format

Levels are stored in the user data directory (`user://Levels/<name>.json`) using a compact key-indexed format to minimize file size and improve loading speed:

```json
{
  "level_name": "My Level",
  "background": "res://resources/backgrounds/background1.png",
  "song_id": "123456",
  "song_name": "Track Title",
  "song_artist": "Artist",
  "ground_colors": {
    "0": "2c6091ff",
    "1": "ffffffff"
  },
  "colors": {
    "0": "ff0000ff",
    "1": "00ff00ff"
  },
  "scene_paths": [
    "res://scenes/objects/obstacles/block.tscn",
    "res://scenes/objects/obstacles/spike.tscn"
  ],
  "items": "1,obj_1,2,0,3,64,4,-128,5,90,9,1,11,0;..."
}
```

### Compact Item Keys

| Key  | Description                                       |
| :--: | :------------------------------------------------ |
| `1`  | Unique instance ID                                |
| `2`  | Scene path index (references `scene_paths` array) |
| `3`  | Snapped X coordinate                              |
| `4`  | Snapped Y coordinate                              |
| `5`  | Rotation (degrees, omitted if `0`)                |
| `6`  | Scale X (omitted if `1.0`)                        |
| `7`  | Scale Y (omitted if `1.0`)                        |
| `8`  | Skew angle (omitted if `0.0`)                     |
| `9`  | Editor layer index                                |
| `10` | Visual Z-index                                    |
| `11` | Color channel index                               |
| `12` | Group IDs (comma-separated within value)          |
| `13` | Target channel (color triggers)                   |
| `14` | Target color hex (color triggers)                 |
| `15` | Fade time in seconds (color triggers)             |

---

## Getting Started

### Prerequisites

- [Godot Engine 4.3+](https://godotengine.org/download) (Compatible with Godot 4.3 – 4.7 standard or .NET builds).

### Installation

1. **Clone the repository**:

   ```bash
   git clone https://github.com/jzhang1890/level_editor.git
   cd level_editor
   ```

2. **Open in Godot**:
   - Launch Godot Engine.
   - Click **Import** and select the `project.godot` file in the cloned folder.
   - Click **Import & Edit**.

3. **Run the Project**:
   - Press `F5` (or click **Play** in the top right of the Godot editor) to start from the Main Menu (`scenes/rooms/main_menu.tscn`).
   - Alternatively, press `F6` while having `editor_root.tscn` or `play_scene.tscn` active to test specific rooms directly.

---

## Export & Platforms

The project is pre-configured with Mobile and Desktop rendering pipelines:

- **Renderer**: Mobile (`rendering/renderer/rendering_method="mobile"`) with D3D12 driver fallback on Windows.
- **Export Presets**: Included `export_presets.cfg` for iOS deployment (`com.jzhan.wayup`) and macOS/Desktop.
- **Storage Locations**:
  - Saved levels: `user://Levels/`
  - Cached music tracks: `user://songs/`
    _(On macOS: `~/Library/Application Support/Godot/app_userdata/Level Editor/`)_

---

## License

This project is licensed under the MIT License - see the project files for full details.
