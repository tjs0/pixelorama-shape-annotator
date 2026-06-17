# Using the Shape Annotator

1. **Select the tool.** Left-click the **Shape Annotator** button in the toolbar (the icon
   is a placeholder box — hover to confirm the tooltip).
2. **Set options** in the Tool Options panel:
   - **Shape:** Rectangle / Circle / Capsule.
   - **Tag:** type a tag (e.g. `hitbox`, `hurtbox`) or pick a known one from the dropdown.
   - **Mode:** *Sprite (all frames)* writes a shared default; *This frame* writes an override
     that replaces the defaults for the current frame only.
   - **Radius:** capsule thickness (shown only for Capsule).
   - **Show annotations:** toggle overlay visibility.
   - **Settings…:** edit the tag→color map.
3. **Draw (click-drag).** You'll see a live outline while dragging; release to commit. No
   pixels are modified.
   - Rectangle: corner to corner. Circle: center then radius. Capsule: spine end to end.
4. **Manage** shapes in the **Shapes** panel — colored swatch + `type [tag]`; click to
   highlight, **X** to delete. Add/delete are undoable (Ctrl+Z / Ctrl+Y).
5. **Colors:** configure per-tag colors via **Edit ▸ Shape Annotator Settings…** or the
   Tool Options **Settings…** button. Unknown tags use the fallback color.
6. **Save** the `.pxo` — annotations persist with the project.
7. **Export:** use **File ▸ Export Shape Atlas…** to pick a path and write `<name>.png` +
   `<name>.atlas.json` (see [atlas-spec.md](atlas-spec.md)). This dedicated command blends
   every frame itself, so it works on desktop where Pixelorama's built-in Export dialog
   can't select a custom format. (On the Web build, the format also appears in the Export
   dialog's format dropdown as *Atlas + Spritesheet (ShapeAnnotator)*.)

## Editing shapes

Set **Action** (in Tool Options) to **Edit** to enter edit mode. In Draw mode the
tool places new shapes; in Edit mode it manipulates existing ones.

**Selecting a shape:** click its row in the Shapes panel, or click directly on its
outline on the canvas. The selected shape gains handles.

**Moving:** drag the body of the shape (away from any handle) to reposition it.

**Resizing:** drag a corner or edge handle (rect/circle) or a rim, endpoint, or
radius handle (capsule) to resize the shape.

**Rotating (rects):** drag the rotate handle that appears above the selected rect.
Hold **Alt** for free rotation; without Alt the angle snaps to the nearest
vertical or horizontal axis (0°/90°/180°/270°).

**Capsule orientation:** capsules are placed vertically and then rotated with the
rotate handle, the same as rects.

**Undo:** every completed drag gesture (move, resize, or rotate) is committed as a
single undo step — Ctrl+Z reverts the whole gesture at once.
