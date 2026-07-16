# Agent creation visual QA

## Source of visual truth

- Figma file: `AI陪伴 伴生` (`9e38GEIBlFmgOdU51Cv5pf`)
- Frames: `25:262`, `45:2089`, `45:2495`, `45:2698`, `45:2900`, `45:3102`, `45:3304`, `45:3506`, `45:3709`
- Captured references: `/tmp/companion-agent-figma/gender.png`, `/tmp/companion-agent-figma/traits.png`, and the seven `/tmp/companion-agent-figma/trait-*.png` states
- Figma source assets were downloaded and converted to transparent Flutter PNG assets; no substitute illustrations or emoji were used.

## Implementation evidence

- Runtime: Flutter iOS Simulator
- Viewport: 390 x 844 points (1170 x 2532 physical pixels at 3x)
- Gender state: `/tmp/companion-agent-ios/gender-v3.png`
- Default traits state: `/tmp/companion-agent-ios/traits-v4.png`
- First trait tooltip state: `/tmp/companion-agent-ios/trait-lively-v1.png`
- Full-view comparisons: `/tmp/companion-agent-ios/gender-compare-v3.png`, `/tmp/companion-agent-ios/traits-compare-v4.png`
- Focused tooltip comparison: `/tmp/companion-agent-ios/tooltip-focused-compare-v1.png`
- Page-transition recording: `/tmp/companion-agent-ios/page-slide-v1.mp4`
- Page-transition frame sequence: `/tmp/companion-agent-ios/page-slide-tail-sheet.png`

## Visual checks

- Typography and copy: title, section labels, hints, card labels, endpoint labels, values, buttons, and all seven tooltip descriptions match the supplied frames.
- Spacing and geometry: 390 x 844 canvas, header placement, 20 px trait-page margins, 56 px cards, 12 px card gaps, 52 px actions, card radii, slider geometry, and tooltip placement were checked against the captured frames.
- Colors and effects: mint page gradient, `#06C893` accent, white cards, gray tooltip, borders, and card/value shadows match the reference appearance.
- Images: top orb, bottom orb, planet, greeting bubble, and both character illustrations use the source Figma artwork at the measured slots.
- Interaction: gender selection, previous/next navigation, random values, seven information overlays, submit guard, and the existing provisioning flow are functional.
- Motion: the 360 ms forward transition moves the gender page left while the traits page enters from the right; the previous action reverses the same page motion. The frame sequence verifies there is no direct page replacement or blank intermediate frame.

## Iteration history

1. Initial capture exposed missing source assets in the test harness; the exact Figma assets were registered in `pubspec.yaml` and verified in the iOS runtime.
2. The first traits capture exposed a 1 px label-row overflow; label and info placement were changed to fixed measured positions.
3. The first tooltip capture exposed a 4 px vertical overflow; tooltip text line height was adjusted while retaining the reference height.
4. Endpoint labels were initially compressed in narrow slots; scale-down fitting restored the complete low/high labels.
5. Post-fix captures were compared side by side at the same viewport. Remaining differences are simulator system chrome only (time and Dynamic Island availability), outside the app surface.
6. The initial implementation directly replaced the two page bodies. It was changed to a non-scrollable two-page `PageView` with an ease-out horizontal transition, guarded against repeated input during motion. The iOS recording and extracted frame sequence confirm the right-to-left entrance and stable final Figma states.

## Final result

passed

---

# Login page visual QA

## Source of visual truth

- Figma file: `AI陪伴 伴生` (`9e38GEIBlFmgOdU51Cv5pf`)
- Login frame: `133:353`
- Reference capture: `/tmp/companion-login-figma.png`
- Product override: WeChat is the primary action; Apple, QQ, and phone are secondary placeholders that currently show an unavailable notice.

## Implementation evidence

- Runtime: Flutter iOS Simulator, unauthenticated state
- Reference canvas: 390 x 844 points, proportionally fitted to the device viewport
- Rebuilt cold-start splash: `/tmp/companion-rebuilt-2200.png`
- Rebuilt cold-start login: `/tmp/companion-rebuilt-3200.png`
- The installed simulator build was relaunched from a terminated state, rather than relying on hot reload.

## Visual checks

- The mint gradient, greeting bubble, planet artwork, stars, primary action, agreement row, divider, and secondary-login row preserve the reference hierarchy.
- WeChat is presented as the primary login action with the official icon; Apple, QQ, and phone entries appear below the secondary-method divider.
- Apple, QQ, and phone taps each show a method-specific `暂未开放` dialog and do not expose the retired email/password form.
- The planet, greeting, stars, and mint circles animate independently with small translation, scale, and rotation values over a 7.6-second sine breathing cycle.
- Each animated decoration owns a repaint boundary and rebuilds only its transform, keeping the static controls and text out of the per-frame animation work.
- Decorative mint circles intentionally use complete circular geometry instead of the cropped Figma exports, so their edges remain visible during the full animation range.
- The hero composition follows the Figma coordinates: the greeting anchors at `19,140`, the planet is shifted right with the same aspect ratio, and the three stars retain their upper-right, lower-left, and lower-right distribution.
- All animated elements keep stable layout bounds and do not collide with the login controls.
- The inherited text decoration is reset at the application boundary; rebuilt cold-start captures confirm that the yellow debug-style lines no longer appear on either splash or login copy.
- The Flutter splash remains for at least two seconds, then crossfades over 650 ms into login. A widget test verifies the pre-transition hold, simultaneous outgoing/incoming middle state, partial opacity, and settled login state.

## Iteration history

1. Replaced rasterized SVG decorations that rendered with white boxes by direct `flutter_svg` assets.
2. Moved the planet inside the canvas and changed paint order so it no longer covers the `Hello` label.
3. Replaced the pre-cropped top and bottom orb exports with full circles after device capture showed permanent flat edges.
4. Captured two final runtime frames; the differing image hashes confirm motion while the controls remain fixed.
5. Recalibrated the decorative layer against node `133:353`: reduced the complete corner circles, moved the planet right, restored the Figma greeting overlap, and painted `Hello` above every background element.
6. Restored the three Figma secondary-login icons and made all unavailable methods return a clear, dismissible notice.
7. Scoped the breathing animation to seven isolated decorative transforms with an `easeInOutSine` curve, eliminating full-page rebuilds during motion.
8. Added a two-second minimum splash and a 650 ms fade transition, then verified it in tests and with a fully rebuilt simulator package.
9. Removed the inherited yellow text decoration globally and verified the fix on a terminated-and-relaunched installed build.

## Final result

passed
