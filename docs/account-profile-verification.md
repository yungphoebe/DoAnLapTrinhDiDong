# Account profile verification

Implemented: authenticated SQL profile and workout persistence; profile/settings/home synchronized; new accounts have null measurements and zero progress; camera records only active elapsed duration on explicit completion; retries preserve session ID. Missing distance/nutrition/recovery remain unavailable. Demo chat history removed.

Checks: backend 12 tests pass; targeted Flutter profile/onboarding/settings/camera/vision checks pass; Flutter analyze clean; web build succeeds (existing CupertinoIcons font warning).

Full Flutter suite run: 39 passed, 15 failed. These failures match the previously documented auth/community tests in camera-ai.md: tests assume old demo flows or depend on the real API at 10.0.2.2:5129, causing HTTP/network errors and timeout. They are not claimed as passing.

Failures from the full run:
- 00:04 +25 -1: D:/DoAnLapTrinhDiDong-AddDatabase/test/auth_flow_test.dart: registration validates confirmation then completes onboarding [E]
- 00:05 +26 -2: D:/DoAnLapTrinhDiDong-AddDatabase/test/auth_flow_test.dart: demo account signs in with the updated email and password [E]
- 00:06 +35 -3: D:/DoAnLapTrinhDiDong-AddDatabase/test/auth_flow_test.dart: email login still opens the demo [E]
- 00:08 +39 -4: D:/DoAnLapTrinhDiDong-AddDatabase/test/app_flow_test.dart: shell preserves community state across tabs at 320px [E]
- 00:08 +39 -5: D:/DoAnLapTrinhDiDong-AddDatabase/test/auth_flow_test.dart: password reset requires contact and shows demo outcome [E]
- 00:11 +39 -6: D:/DoAnLapTrinhDiDong-AddDatabase/test/social_test.dart: community like can be added and removed [E]
- 00:15 +39 -7: D:/DoAnLapTrinhDiDong-AddDatabase/test/social_test.dart: community keeps a submitted local comment [E]
- 00:18 +39 -8: D:/DoAnLapTrinhDiDong-AddDatabase/test/social_test.dart: community can create, edit and delete a post [E]
- 00:20 +39 -9: D:/DoAnLapTrinhDiDong-AddDatabase/test/social_test.dart: trainer tab, connection and filters update visible state [E]
- 00:22 +39 -10: D:/DoAnLapTrinhDiDong-AddDatabase/test/post_controller_test.dart: loadPosts exposes seeded posts from the API [E]
- 00:43 +39 -11: D:/DoAnLapTrinhDiDong-AddDatabase/test/post_controller_test.dart: createPost trims content and inserts the newest post first [E]
- 01:04 +39 -12: D:/DoAnLapTrinhDiDong-AddDatabase/test/post_controller_test.dart: createPost ignores blank content [E]
- 01:25 +39 -13: D:/DoAnLapTrinhDiDong-AddDatabase/test/post_controller_test.dart: updatePost replaces content and keeps the same post id [E]
- 01:46 +39 -14: D:/DoAnLapTrinhDiDong-AddDatabase/test/post_controller_test.dart: deletePost removes only the matching post [E]
- 02:07 +39 -15: D:/DoAnLapTrinhDiDong-AddDatabase/test/post_controller_test.dart: toggleLike updates the liked state and like count [E]