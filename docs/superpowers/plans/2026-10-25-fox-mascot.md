# Home fox mascot animation

User requests the supplied teal robotic fox on Home, with reminder/teasing chat bubbles and multiple animations/states.

Approach: Generate one transparent 4-column, 5-row sprite atlas from the supplied reference; play four frames for each of idle, greeting, reminding (curl), teasing (impatient), celebrating. Compared with moving the same still image or adding a skeletal-animation dependency, a sprite atlas gives distinct expressions and gestures without adding a package.

Keep existing saved-progress and opt-in tone logic. Display only on Home, hide on other tabs/keyboard, and never tease on unknown progress. Stop animation in background, offstage, and under reduced-motion settings.

Files: `lib/widgets/training_pet.dart`, `lib/screens/shell.dart`, `lib/screens/training_bot.dart`, `assets/images/gym_fox_sprites.png`, and `test/training_pet_test.dart`. The existing asset-directory declaration covers the new PNG.

Checks: state transitions, Home-only visibility, animation frame advancement/reduced motion, existing bot/settings tests, analyzer and actual rendered screenshot.

Asset: `assets/images/gym_fox_sprites.png`, generated with the built-in Imagegen tool using the user's reference image. RGBA PNG, 1122×1402, transparent corners verified. Rendered home preview: `build/fox_home_preview.png`. Character edges inspected at the actual 112px display size.

Final generation prompt:
> Create a production game sprite sheet based closely on the attached reference image: the SAME cute teal/cyan robotic fox gym mascot, ivory face and armor, orange inner ears and cheek accents, dark navy joints, glowing cyan headphones and chest triangle, large fluffy tail, small dumbbell. Preserve character identity, proportions and illustrated polished soft 3D style. OUTPUT ONE TRANSPARENT PNG SPRITE SHEET, exactly 4 columns by 5 rows, uniform square cells with equal dimensions, no labels, no text, no grid lines, no ground shadows, no extra props except dumbbell. Entire sheet aspect ratio 4:5. Each character fully contained within its cell with 12% transparent margin, same body scale and aligned feet baseline in every cell. Each row is a short coherent FOUR FRAME animation sequence: row 1 idle relaxed breathing with a blink, row 2 cheerful greeting wave with empty hand (dumbbell in other hand), row 3 encouraging workout reminder doing a dumbbell curl, row 4 playful impatient teasing with raised eyebrow, folded free arm and foot tap (not hostile), row 5 joyful celebration little jump and victorious raised dumbbell. Exactly 20 full body foxes total. Clean actual alpha background. These frames will be cropped by exact equal cell boundaries in a Flutter app, so strict grid layout and no overlaps are essential.

Verification: 26 focused Flutter tests pass, including Home-only visibility, greeting/reminder/teasing/celebration transitions, unknown-data behavior, frame playback, reduced motion, offstage/background pauses, actions and small-screen layout. Independent code review found no blocker. Physical-device testing remains outstanding.
