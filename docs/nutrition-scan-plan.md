# Image nutrition scan

Goal: analyze the selected meal photograph with local LMStudio Vision and show estimated kcal, protein, carbs, fat and portion weight; save exactly the reviewed values to the user's diary.

Approach: keep the existing Flutter screen and authenticated nutrition endpoints. Backend replaces the fixed 200 kcal placeholder with a validated image request and JSON estimate. Custom meal items use stored nutrition snapshots, separate from the shared food catalog. Image estimates are explicitly approximate and editable; AI failures never produce a fake meal.

1. Backend: nutrition analysis service, nutrition DTOs/controller, meal-item snapshot model/configuration/migration. Tests first for vision response validation, failure handling, and scan/save/update/summary round trips.
2. Flutter: `lib/models/nutrition.dart`, `lib/services/nutrition_service.dart`, `lib/screens/nutrition.dart`. Distinguish scan IDs from catalog food IDs, send custom macros, show and edit all four values, refresh totals after mutations. Tests first in `test/nutrition_service_test.dart` and screen tests.
3. Verify: backend solution tests, targeted Flutter tests/analyzer then full Flutter suite; independent code review; apply additive database migration and test a real image through analyze/save/read/summary against the running backend.

No new cloud service or image-generation dependency. Preserve unrelated in-progress edits and do not create a worktree.
