# Feed, likes and comments API implementation plan

> Use superpowers:executing-plans inline; the user said “làm cho tôi” after the written API spec. Continue through implementation and verification without another approval handoff.

**Goal:** Persist comments, return real comment counts and enforce content ownership on the existing feed API.
**Architecture:** PostComment table with an idempotency GUID; dedicated authenticated PostCommentsController; retain feed and like contracts, adding commentCount.
**Tech stack:** ASP.NET Core 9, EF Core, SQL Server, xUnit/WebApplicationFactory.
**Spec:** docs/superpowers/specs/2026-10-20-feed-comments-api-design.md.

## Constraints and review focus

- JWT supplies author identity; only author/admin mutates content, including comments on someone else's post.
- Preserve existing database and unrelated uncommitted work; no frontend or post creation changes.
- Content 1–1000 characters after trim; pageSize 1–100; deterministic CreatedAt/Id order.
- Concurrent retries must not duplicate comments; edited comments reject old creation replay.
- A comment ID under the wrong post URL must never mutate or expose that comment.

## Task 1: API behavior tests

Files: backend/AiGym.Api.Tests/FeedCommentsApiTests.cs.
- [x] Write HTTP tests against actual auth middleware: persistence/idempotency, invalid inputs, pagination, wrong post, owner/non-owner/admin, feed counts and post edit length.
- [x] Run filtered tests with --artifacts-path .artifacts/comments; confirm missing endpoint/count failures before implementation.

## Task 2: Comment storage and endpoints

Files: Models/PostComment.cs, Data/CommentSchema.cs, Dtos/CommentDtos.cs, Controllers/PostCommentsController.cs; ApplicationDbContext, DatabaseSeeder, PostDtos, PostsController.
Interfaces: GET/POST /api/posts/{postId}/comments; PUT/DELETE /api/posts/{postId}/comments/{commentId}; flat CommentResponse with author, timestamps and content; feed adds commentCount.
- [x] Add EF mapping and additive schema upgrade with FK cascade on PostId and NO ACTION on AuthorId.
- [x] Implement validated pagination, SQL range-locked idempotent insert, retry conflict handling, author/admin edit/delete and feed counts.
- [x] Run Task 1 until green; no changes to existing POST /api/posts.

## Task 3: SQL Server proof

Files: backend/AiGym.Api.Tests/CommentsSqlServerTests.cs.
- [x] Test upgrade twice against a randomly named isolated database, concurrent creates/retries, edited retry conflict, reopened contexts, FK constraints and post-delete cascades.
- [x] Run full backend suite with AIGYM_TEST_SQLSERVER and isolated artifacts; preserve user's running API process.

## Task 4: Review and documentation

Files: backend/README.md and this ledger.
- [x] Document endpoints, rights, errors, restart and test commands.
- [x] Fresh independent review of this change only; fix important findings and verify again.
- [x] Run diff checks and record final test evidence/limitations; leave product changes uncommitted for user review.

## Execution ledger

- Ruling: continue inline in the shared checkout as in the previous implementation; user explicitly requested changes to this IDE project, which already contains unrelated uncommitted work. Do not move, reset or commit that work.
- Pre-flight: Task 1 uses HTTP JSON only, so RED can be observed before product types exist. Task 2 produces CommentResponse/EF schema consumed by Task 3; Task 3 uses the same controller directly with separate SQL contexts. Use existing SqlServerFact and ApiFactory helpers.
- Task 1 RED: all 5 new HTTP tests failed (comments 404 and oversized post edit returned 200). Task 2 GREEN: all 5 passed after implementation.
- Task 3: full backend suite passed 24/24, none skipped, including LocalDB upgrade twice, concurrent 12-request comment deduplication, reopened reads, FKs, cascades and existing like concurrency tests.
- Independent read-only review reported no actionable critical/important findings.
- Additional SQL UTC regression: CreatedAt/UpdatedAt read as Unspecified, reproduced with 2 failing assertions; comment timestamp conversions now restore UTC on read. Full suite then passed 24/24 again with no warnings.
- Final check: git diff --check passed. No frontend changes or browser/device test needed for this backend-only scope. Existing POST /api/posts implementation was retained.
