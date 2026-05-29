# Sandbox-Style Terrain Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an experimental infinite-map terrain paint mode inspired by C-Wenge/Sandbox so terrain edge tiles are selected from global coordinates, not only from currently loaded chunk cells.

**Architecture:** Keep the existing `WorldGenerator` chunk, resource, decoration, HUD, and player flow. Add a terrain paint mode that manually chooses terrain atlas tiles from each cell's global 8-neighbor mask, mirroring Sandbox's global-neighbor auto-tile idea while staying inside the current TileMapLayer setup.

**Tech Stack:** Godot 4.6 GDScript, `TileMapLayer`, `TileSetAtlasSource`, existing script-based tests.

---

### Task 1: Lock In Desired Global Neighbor Behavior

**Files:**
- Modify: `tests/world_generator_terrain_test.gd`

- [ ] **Step 1: Add a failing test**

Add assertions that enable the new experimental mode and require the generated overlay tile at a chunk border to match the terrain tile selected from the global neighbor mask.

- [ ] **Step 2: Run the test**

Run: `/Users/wxb/Downloads/Godot.app/Contents/MacOS/Godot --headless --path /Users/wxb/cc/_active/kingdom-echoes -s tests/world_generator_terrain_test.gd`

Expected before implementation: failure because the new mode/methods are missing.

### Task 2: Implement Sandbox-Style Terrain Paint Mode

**Files:**
- Modify: `scripts/game/world_generator.gd`

- [ ] **Step 1: Add the mode flag**

Expose `TERRAIN_PAINT_GODOT_CONNECT` and `TERRAIN_PAINT_GLOBAL_NEIGHBORS`, defaulting to the current Godot behavior.

- [ ] **Step 2: Build terrain tile lookup by neighbor bits**

Cache tiles by `terrain_id` and an 8-bit global neighbor mask. Normalize diagonal bits the same way Sandbox's `AutoTile` does.

- [ ] **Step 3: Paint overlay cells from global coordinates**

When the experimental mode is active, set overlay cells directly from the cached lookup instead of calling `set_cells_terrain_connect()`. Use `_get_overlay_terrain_at()` for the current cell and all eight neighbors so tile choice is stable before adjacent chunks are loaded.

- [ ] **Step 4: Keep current mode available**

Leave current `set_cells_terrain_connect()` path intact for comparison and quick rollback.

### Task 3: Wire Experiment On For Local Verification

**Files:**
- Modify: `scripts/game/kingdom_echoes.gd`

- [ ] **Step 1: Enable the experimental mode after terrain tileset setup**

Call the new setter from `_configure_terrain_tileset()` so the running game uses the Sandbox-style terrain path.

- [ ] **Step 2: Run the focused test**

Run the Godot test command from Task 1 and confirm it passes.

- [ ] **Step 3: Run a headless smoke check**

Run the project headless briefly to catch parse/runtime errors.
