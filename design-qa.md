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

---

# Chat voice recording visual QA

**Source visual truth**

- `/Users/songtao/Library/Containers/com.tencent.xinWeChat/Data/Documents/xwechat_files/pp_tingfenging__03cb/temp/RWTemp/2026-07/ee9b29974a98b03945babe57c5ffa49e.jpg`

**Rendered implementation**

- `/tmp/companion_voice_overlay_v3_sim.png`
- Full side-by-side comparison: `/tmp/companion_voice_overlay_comparison_v3_sim.png`
- Viewport: iPhone 17 Pro Max simulator, 440 × 956 logical pixels, 1320 × 2868 physical pixels.
- State: recording is active, pointer remains in the default release-to-send region.

**Full-view comparison evidence**

The source and implementation were normalized to the same height and placed in one comparison image. The implementation preserves the source hierarchy: dimmed conversation, bright lime recording surface near the middle, two lower gesture targets, and a high-contrast release-to-send surface at the bottom. The recording surface, target labels, and bottom action remain readable at the full comparison scale.

**Focused region comparison evidence**

A separate crop was not needed because the 2358 × 2556 full comparison keeps the central recording surface and bottom controls clearly readable. The simulator screenshot was also inspected at original resolution for typography, icon alignment, radii, shadows, and safe-area placement.

**Findings**

- No actionable P0/P1/P2 mismatch remains.
- Fonts and typography: iOS system Chinese text renders cleanly; hierarchy and weights match the reference intent. Labels do not wrap or truncate.
- Spacing and layout rhythm: the central recording surface and bottom actions follow the same vertical hierarchy and remain inside safe areas.
- Colors and tokens: the lime recording color, dark scrim, neutral gesture targets, and white send surface closely match the reference.
- Image and asset fidelity: no raster asset was needed; all visible symbols use the platform Material/Cupertino icon libraries. No handmade SVG or placeholder asset is present.
- Copy and content: `取消`, `滑到这里  转文字`, and `松开  发送` are concise and match the requested interaction.
- Accessibility and behavior: the microphone status has a semantic recording-duration label; the press interaction has explicit cancel, convert, and send states. Widget tests cover the visible labels and recording state.
- P3 accepted difference: the reference uses organic curved gesture regions and a small speech-bubble tail. The implementation uses Companion's rounded control language and standard platform icons for clearer hit targets and avoids a code-drawn decorative asset.

**Comparison history**

1. Initial simulator capture `/tmp/companion_voice_overlay.png`: the recording card sat too high and exposed a timer not present in the source. The card was moved toward the visual center and the timer was retained only as an accessibility label.
2. Second capture `/tmp/companion_voice_overlay_v2.png`: the card proportions were slightly taller than the source. Height was reduced from 106 to 96 logical pixels and vertical alignment was adjusted.
3. Final capture `/tmp/companion_voice_overlay_v3_sim.png`: post-fix comparison shows no remaining P0/P1/P2 issue.

**Primary interactions tested**

- Default release-to-send state renders.
- Cancel and convert-to-text targets render with distinct labels.
- Recording status exposes an accessible duration label.
- Simulator preview launched without a Dart/runtime exception.

**Implementation checklist**

- [x] Match source hierarchy and safe-area layout.
- [x] Use real platform icons.
- [x] Verify visible copy and Chinese font rendering on iOS.
- [x] Verify central card and lower gesture targets at the target viewport.
- [x] Re-run widget tests after visual fixes.

final result: passed

---

# Chat voice recording visual QA - restrained green redesign

## Source and implementation evidence

- Selected reference: `/Users/songtao/.codex/generated_images/019f6b7f-d443-72f0-a3f7-94e62a3918af/exec-2dde1d4a-aed3-4638-874a-4a6a8527c0ca.png`
- iOS implementation capture: `/Users/songtao/.codex/visualizations/2026/07/16/019f6b7f-d443-72f0-a3f7-94e62a3918af/voice-recording-overlay-ios.png`
- Side-by-side comparison: `/Users/songtao/.codex/visualizations/2026/07/16/019f6b7f-d443-72f0-a3f7-94e62a3918af/voice-recording-design-comparison.png`
- Target viewport: 390 x 844 logical pixels.
- State: recording for 12 seconds with send voice as the default release action.

## Findings

- P0: none.
- P1: none. The action hierarchy, dimmed chat context, recording capsule, paired cancel/text targets, and green release target match the selected direction.
- P2: the implementation keeps the release target above the app's persistent bottom navigation area; this is an intentional product-context adjustment from the standalone mock.
- Motion: overlay entry uses a 190 ms opacity/translation transition; target changes use 110 ms scale/color transitions; waveform repainting is isolated and driven at 80 ms intervals.
- Accessibility: recording state and all release targets expose explicit semantics labels; reduced-motion settings disable the overlay entrance transition.

## Iteration history

1. Replaced the previous neon/arc presentation with the selected restrained green layout.
2. Rendered the implementation on an iOS 390 x 844 simulator with real Chinese system fonts.
3. Compared the reference and implementation in one side-by-side image and retained the app-specific green token and bottom-navigation clearance.

final result: passed

---

# Chat voice recording visual QA - full-screen modal correction

## Source and implementation evidence

- Device reference: `/var/folders/4d/sgc342hn4bg789gjfdsrl5t80000gn/T/codex-clipboard-9a879a92-b71c-4c1e-9262-e27b9d212b69.png`
- iOS implementation capture: `/Users/songtao/.codex/visualizations/2026/07/16/019f6b7f-d443-72f0-a3f7-94e62a3918af/voice-recording-overlay-fullscreen-fix.png`
- Side-by-side comparison: `/Users/songtao/.codex/visualizations/2026/07/16/019f6b7f-d443-72f0-a3f7-94e62a3918af/voice-recording-overlay-fullscreen-comparison.png`
- Target viewport: 390 x 844 logical pixels, 1170 x 2532 physical pixels.
- State: recording for seven seconds with the pointer inside the cancel target.

## Findings

- P0: none.
- P1: none. The recording overlay now occupies the parent shell, so the floating bottom navigation is removed from the visible modal state instead of remaining above the chat-page scrim.
- P2: none. The selected cancel target uses the requested red icon, label, outline, and pale red fill while convert-to-text remains neutral and send remains green.
- Opacity: scrim alpha was reduced from `0x8F` to `0x70`; recording and action surfaces were also reduced while retaining readable contrast against the conversation.
- Motion: the navigation exits with the existing 180/260 ms opacity and position transitions; the overlay entrance and 110 ms target transitions remain unchanged and fluid.
- Behavior: the active long-press pointer continues to be handled by the chat composer, while the shell-level overlay prevents new touches from reaching underlying navigation controls.

## Verification

- The reference and simulator capture were normalized to the same viewport and inspected together.
- The comparison confirms that the formerly visible floating navigation is absent in the corrected modal state.
- The selected cancel target is visually distinct in red without introducing an additional animation or decorative effect.
- Widget coverage verifies the lower scrim opacity and red cancel selected-state tokens.

final result: passed
