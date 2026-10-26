#!/bin/bash
# One review round for a Blender-built model (art/RECIPE.md): build it in the T-pose, render its eight views in the
# studio (data/art.json "turnaround") and lay them beside its reference sheet.
#   art/tools/turnaround.sh art/characters/knit_camper OUT_DIR [ZOOM]
# ZOOM (default 1) brings the studio camera that many times closer, for a model that many times smaller than the
# 1.48 m camper: about 4 for a hand-held prop.
# The folder holds build_<id>.py and, if there is a sheet, reference.json; <id> is the folder's name and the model's
# id in data/models.json. Needs blender, godot, xvfb-run and the Vulkan software driver (mesa-vulkan-drivers).
DIR=${1%/}
NAME=$(basename "$DIR")
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
mkdir -p "$2" && OUT=$(cd "$2" && pwd)
cd "$ROOT" || exit 1
# A fresh clone has no import cache, and the capture script then fails to parse: import once first.
[ -d .godot/imported ] || godot --headless --import > /dev/null 2>&1
rm -f "$OUT/tpose.glb"
blender --background --factory-startup --python "$DIR/build_$NAME.py" -- "$OUT/tpose.glb" --pose=t 2>&1 \
  | grep -E "verts|height|shade|Error|Traceback|line [0-9]"
[ -f "$OUT/tpose.glb" ] || { echo "the build failed"; exit 1; }
xvfb-run -a -s "-screen 0 1920x1080x24" godot --script res://scripts/tools/capture.gd --resolution 1000x920 \
  -- --out="$OUT" --turn="$NAME" --glb="$OUT/tpose.glb" --zoom="${3:-1}" > "$OUT/capture.log" 2>&1
if grep -E "SCRIPT ERROR|Parse Error|can't read" "$OUT/capture.log"; then exit 1; fi
# Without the Vulkan software driver Godot falls back to OpenGL, whose colours come out far more saturated: such a
# round can't be judged against the sheet (art/RECIPE.md, "Mistakes already made").
if grep -q "switching to OpenGL" "$OUT/capture.log"; then
  echo "rendered with OpenGL, not Vulkan: install mesa-vulkan-drivers and run the round again"; exit 1
fi
[ -f "$OUT/turn_front.png" ] || { echo "no renders; see $OUT/capture.log"; exit 1; }
if [ -f "$DIR/reference.json" ]; then
  python3 art/tools/compare.py sheets "$OUT" "$DIR/reference.json"
else
  echo "renders in $OUT (no reference.json, so no sheets)"
fi
