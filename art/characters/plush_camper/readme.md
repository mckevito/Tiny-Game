# Plush camper — proposed art pack

Original felt-and-fabric miniature character, for owner review. Not connected to gameplay by this PR.

## Files

- `plush_camper.glb`: game asset, embedded mesh/skin/animation data, no textures.
- `plush_camper.gltf`: editable, self-contained glTF 2.0 source; import into Blender or another glTF editor. This is the supplied native editable interchange source instead of a `.blend` file.
- `build_plush_camper.py`: original procedural authoring source. Run with Python 3 and NumPy to regenerate both formats and the manifest. Outputs resolve beside the script; no absolute paths are embedded in the assets.
- `preview.png`: software-rendered views and animation poses from the exported GLB, not Godot screenshots.
- `asset_manifest.json`, `validation.json`: measured properties and export checks.

## Contract

Height 1.000 m including hat, 3,324 triangles including every accessory and stitch. Metres; +Y up; front -Z. Root is at the ground midpoint between boots. Bind pose has no root offset or scale. Smooth vertex normals; matte PBR materials, no simulated fur or fabric. All geometry is original.

The skeleton has root, hips, spine, head, paired upper arms/hands and thighs/feet, plus named hair_socket, hat_socket and backpack_socket bones. Each accessory is a separate mesh rigidly weighted to its corresponding socket bone. Hat brim/badge, hair lock and backpack pocket are separate companion meshes on the same socket. Hide those companions with their accessory. Straps are separate meshes weighted to spine. Remove the straps too when hiding the backpack.

Material resources are named body (cream), clothing (pond blue), hat (rust), boots (moss), thread (honey). All colors use the requested palette. Swap by material name rather than surface index. Hat material also colors trousers/backpack; boots also colors hair and facial embroidery. For independent recoloring, duplicate the material on the desired meshes during integration. No texture files or external resources.

## Animation clips

30 fps. Frame counts below include the repeated closing sample: a 60-frame interval has 61 samples at frames 0–60.

| Name | Frames | Samples | Duration | Playback |
|---|---|---|---|---|
| idle | 0–60 | 61 | 2.0 s | seamless loop |
| walk | 0–30 | 31 | 1.0 s | seamless in-place loop |
| wave | 0–60 | 61 | 2.0 s | one-shot, returns to rest |
| sit | 0–45 | 46 | 1.5 s | transition into sitting, hold last pose |
| carry | 0–60 | 61 | 2.0 s | stationary carrying pose with breathing loop |

The glTF extras mark intended loops, but glTF has no universal playback loop setting: configure Godot animation looping for idle/walk/carry on import. Idle and walk endpoint transforms match within 1e-6. Walk is in place; game movement supplies translation. Carry contains no carried prop and no walking leg motion; layering or carry-walk blending belongs in the later integration PR. Sit is a stylized low-seat pose; align the game seat to it. Meshes use segmented plush construction with rigid weights, not a continuous deformation surface.

## Validation and limits

Checked exported GLB header/length, triangle total, bounds, lowercase snake_case names, valid indices, normalized weights, finite animation channels and matching idle/walk endpoints. Inspected eight rendered views/poses including all five animations. No external URIs, images, personal data or absolute source paths are stored in GLB/glTF.

Blender could not be installed from the available download sources, so no `.blend` is claimed. Godot runtime import/playback has not been verified locally; this pack needs owner art review and a Godot integration check before adoption. The neutral matte materials are intentionally independent from the game's procedural felt shader. Claude can adapt that shader in a separate gameplay/integration PR.

AI-generated: OpenAI Codex using an original Python/NumPy mesh and animation generator. Licensed CC BY 4.0; attribution: The Our Little Campground contributors.
