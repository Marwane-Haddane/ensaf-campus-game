# Entrance bug fixes

The three supplied boards are used as design targets. The screenshots below are direct captures of the implemented game, not edited target images.

## Atrium front entrance

Two slim black-framed glass leaves now operate as a real double door with handles, outer hinge pivots, one-second easing, solid moving collision and contextual E interaction. The original fixed sidelights, tall glazing and upper transoms remain in place. Only the central lower divider and obsolete static door panels/handles were replaced.

The threshold and front landing meet at y=1.814. The original stair flight into the lower hall remains traversable. Repaired tiles share a world-aligned 60 cm pattern with the portico.

![Atrium double doors open](../tools/entrance-fixed-atrium-front-open.png)

## Side entrance and floor gap

The original gap at x about -3.5 to -2.6, z about -105 to -105.6 dropped to the sunken foundation at y=.42. It is now a visible solid tiled landing at y=1.814, continuous with the adjacent routes. The extended rail protects the open stair edge without crossing the path.

The former static side panel is now a separate hinged glass door. It opens onto the broad exterior portico so the open leaf does not block the narrow internal corridor. Its threshold is low and its collision follows the actual leaf.

![Repaired side landing](../tools/entrance-fixed-side-landing.png)

## Reception sliding entrance

Following the user's confirmed choice, the central reception entrance uses two separate sliding leaves rather than the earlier single right-hinged leaf. The leaves park in front of fixed outer sidelights on a separate track plane that clears their rear handles. The original upper framing stays fixed.

Three old plaza terrace-step sections were found crossing the reception floor at heights .98, 1.09 and 1.20 m. Their reception-frontage portions were trimmed, preserving each step outside that frontage. A small solid strip connects the original reception finish to its original threshold. There are no raised terrace risers across the open entrance.

![Reception sliding entrance open](../tools/entrance-fixed-reception-open.png)

## Verification

- 84 entrance regression checks pass in headless and actual native Compatibility rendering.
- The PC/server integration regression passes 81 checks; the PC-hover regression passes 135, including switching to a valid nearby door prompt.
- 39 independent door-physics checks pass, including eased timing, moving collision, anti-crush handling, range and obstruction.
- The player is tested walking through closed/open doors, across the old floor gap, along the side corridor with its door open, and down the original adjacent stair.
- Dense floor rays confirm continuity across the repaired landing and front threshold.
- Door movement freezes under the pause menu and resumes afterwards.
- Eight native screenshots record closed/open reception, atrium and side doors plus the repaired landing and inside view.

Results: tools/entrance_bugfix_test.json and tools/door_physics_test.json. Native log: tools/entrance-bugfix-final-native.log. The source campus GLB and Blender project remain unchanged; fixes are actual runtime geometry, transforms, materials and physics in the game. Antigravity's optional visual-polish module is separate.
