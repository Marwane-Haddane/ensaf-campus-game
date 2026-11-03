# Campus visual QA: six destinations

Reviewed 2026-11-01 against the provided photo reference and the six saved 2026-10-31 21:23 destination captures. These are baseline findings, not a claim about the lighting/material changes currently in progress. No GPU run, source asset edit, or runtime edit was performed for this review.

1. **Reception / response desk — usable composition, weak material depth.** `campus-preview.png` shows clear workstation placement and recognizable authored equipment. The diagonal shadow over the lower counter has a visible stair-step edge, distinct from its fine horizontal material pattern. Soft shadow filtering and increased near shadow resolution are the appropriate first fixes. The response equipment sits on the correct desk surface; the bright blue PC element is authored emissive material, not an absent map.
2. **Auditorium rear aisle — complete and readable, repetitive lines alias.** `auditorium-preview.png` has a clear aisle and stage. Thin, high-contrast ceiling seams become a dashed diagonal grid toward the stage. Source tiles are 591 mm wide with 9 mm gaps; wall trim also creates subpixel edges. Keep the geometry, soften grout contrast and use 4x MSAA if performance permits. Broad lighting changes should preserve the darker upholstered seating and red aisle.
3. **Glazed building entrance — strong architectural framing, excessive glare and glass layering.** `glazed-building-preview.png` shows floor/white surfaces losing detail in the daylight. Looking through multiple glass planes also veils the interior. Reduce excessive light contribution and preserve a low tint/low alpha glass finish; avoid changing opaque mullions merely because their node role is `glass`. This view is the best exterior/interior exposure check.
4. **Security training area — closest reference composition, insufficient grounding in shade.** `security-assets-preview.png` already matches the reference's desk/chair/rack arrangement well. The sunny window strip is very bright while the racks and desk have little visible contact shading on the shaded floor. Rebalanced global lighting should be checked here before introducing local fills. If required, one restrained downward shadowed SpotLight near the occupied zone provides actual furniture shadows at lower shadow-map cost than an OmniLight.
5. **Auditorium teaching desk — accurate authored props, camera dominated by equipment.** `teaching-assets-preview.png` confirms intact wood grain, keyboard/mouse detail and tower parts. The pure blue tower panel is source material `mt_pc_led`: base factor `(0, 0.00239187, 0.800007)` and emission `(0, 0.00254211, 1)`. Any dark cool metal substitution is an intentional runtime art-direction change and should affect that named material only, with originals unchanged.
6. **Campus plaza — layout reads, largest exterior polish gap.** `plaza-preview.png` shows overbright paving/facade surfaces, angular tree silhouettes, and very thin fence lines. The plaza source crown surfaces already have smooth normals: each connected lobe has 42 vertices / 80 triangles, with average normal-to-radial dot 0.986–0.996. Runtime `lod_bias=0.30` plus generated import LODs can make that silhouette coarser. Restore a higher LOD bias for `Campus plaza shade tree*` and `R3 Garden tree*`, and preserve it in render batches before considering new geometry.

## Source checks that separate causes

- `D7 polished lower hall floor` and the auditorium ceiling have correct flat cardinal normals. There is no evidence that malformed normals cause broad floor streaks.
- E6 reception finish top is 12 mm above its base floor; those two surfaces are not coplanar.
- D7 entrance/portico slab tops overlap over 8.763 square metres at y=1.8, but stone finishes at y=1.812–1.814 cover most of that region. This overlap does not establish the cause of the broad hall stripes.
- One exact duplicate architecture pair exists: `D7 short facade fine mullion.005` and `.006`.
- E5 facade has 22 horizontal and 108 vertical modeled joints, each 4 mm wide. Their distant high-contrast aliasing should be treated separately from shadow acne.
- Godot 4.3 default directional light values read from the installed runtime: `shadow_bias=0.1`, `shadow_normal_bias=2.0`, `directional_shadow_blend_splits=false`. The baseline uses 2048 shadows and a 45 m shadow range. Modest normal-bias reduction can improve contact; reducing depth bias aggressively can introduce acne.

## Low-cost order of fixes

1. Rebalance light and surface values against **both** plaza and D entrance, then verify the auditorium remains readable.
2. Improve shadow filtering/near resolution and blend cascade splits; compare counter and D rear-wall edges at the same camera pose.
3. Use 4x MSAA if the Intel Iris frame rate remains acceptable, with lower-contrast fine joints instead of amplified surface noise.
4. Preserve crown source LOD before modifying normals or importing any vegetation. The owned individual-leaf E6/D7 trees should remain untouched by crown-only changes.
5. Add one small local shadowed spotlight only if shaded furniture still looks detached. Suggested D starting point: `(0,7,-112)`, range 8 m, cone 55–65 degrees, neutral light, energy 0.25–0.4, normal bias around 0.5. This is a tuning recipe, not a verified final placement.

Only visual readability is assessed. Input focus, keyboard navigation, complete accessibility compliance and final frame rate require the root agent's current build checks. See `polish_qa_geometry.json`, `polish_qa_canopy.json` and their read-only inspection scripts for exact source measurements.
