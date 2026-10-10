# M1 Security Tests

This document records the M1 RLS hardening tests and the deliberate mutation checks run against GitHub Actions. Mutation PRs were closed without merging; the intended implementation is in PR #2.

## Mutation Evidence

| Requirement | Temporary mutation | Expected red tests | CI evidence |
|---|---|---|---|
| 3(a) Profile privilege columns | Replace the column-only profile UPDATE grant with `GRANT UPDATE ON public.profiles TO authenticated` | T15-T18: reject self-promotion/self-ban and preserve the original `role`/`is_banned` values | [Run #29](https://github.com/HienIT1210/Food-map/actions/runs/37279705867): `Failed test 17` and `18`: `caught: no exception`, `wanted: 42501`; `Failed test 19`: `have: admin`, `want: user`; `Failed test 20`: `have: true`, `want: false`. Failed 4/38. |
| 3(b) Review INSERT ownership | Temporarily replace the `reviews` INSERT `WITH CHECK` expression with `true` | T20: B cannot insert a review using A's `user_id` | [Run #30](https://github.com/HienIT1210/Food-map/actions/runs/37280036135): `Failed test 22 (T20)`: `caught: no exception`, `wanted: 42501`. T22 and T33 also failed because this broad mutation also permitted anon and banned-user inserts. Failed 3/38. |
| 3(c) Anon direct access | Add permissive `SELECT` and `INSERT` policies on `reviews` for `anon` | T21-T22: anon sees zero direct rows and cannot insert | [Run #31](https://github.com/HienIT1210/Food-map/actions/runs/37280345526): `Failed test 23 (T21)`: `have: 16`, `want: 0`; `Failed test 24 (T22)`: `caught: no exception`, `wanted: 42501`. Failed 2/38. |

After restoring the intended policies, [Run #32](https://github.com/HienIT1210/Food-map/actions/runs/37280676065) passed: `Files=2, Tests=42`, `Result: PASS`.

The implementation branch's full CI also passed in [Run #28](https://github.com/HienIT1210/Food-map/actions/runs/37278959259). `01_rls_test.sql` reports 38 assertions and `02_auth_trigger_test.sql` reports 4. Strict `extensions.finish(true)` makes TAP assertion/plan failures fatal.

## New Assertion Map

| Test | Requirement | Assertion |
|---|---|---|
| T15 | 3(a) | A regular user cannot promote their own profile |
| T16 | 3(a) | A regular user cannot change their own ban status |
| T17 | 3(a) | Rejected promotion leaves `role = 'user'` |
| T18 | 3(a) | Rejected self-ban leaves `is_banned = false` |
| T19 | 3(a) | User-editable `display_name` remains writable |
| T20 | 3(b) | B cannot insert a review with A's `user_id` |
| T21 | 3(c) | `anon` reads zero rows directly from `reviews` |
| T22 | 3(c) | `anon` cannot insert a review |
| T23 | 3(d) | A regular user cannot change `avg_rating` |
| T24 | 3(d) | A regular user cannot change `review_count` |
| T25 | 3(d) | A regular user cannot change restaurant `status` |
| T26-T28 | 3(e) | A sees its own report, block, and saved item |
| T29-T31 | 3(e) | B cannot see A's reports, blocks, or saved items |
| T32 | 3(e) | A regular user cannot read `admin_audit_log` |
| T33 | 3(f) | A banned user cannot insert a review |
| T34 | 3(g) | Anonymous review accepts a non-identifying photo path |
| T35 | 3(g) | Anonymous review rejects a path containing the owner's UUID |
| T36 | 3(g) | A review with an identifying photo path cannot be switched to anonymous |

T5 checks review UPDATE/DELETE isolation against its own fixture row so a successful destructive mutation does not affect T8 or T14.

## Repeat the Mutations

Run one mutation at a time on a temporary branch based on the security implementation branch (or `main` after merge):

```powershell
git switch security/m1-security-hardening
git switch -c test/security-mutation-check
```

Apply only the selected mutation in the new migration, commit it, push the branch, and open a PR against the implementation branch. Wait for the `Database (M1+)` job and record the TAP test name and failure lines. Restore the intended migration before the next mutation so each run has one mutation. Do not merge the mutation PR. Close it and delete both the remote and local temporary branch afterward.

For 3(a), broaden the `profiles` UPDATE grant to table-level UPDATE. For 3(b), temporarily use `WITH CHECK (true)` on the review INSERT policy. For 3(c), add permissive `anon` SELECT and INSERT policies on `public.reviews`.

The migration file `20261005100000_security_hardening.sql` is forward-only; after PR #2 is merged, apply it to Supabase Cloud with `npx supabase db push`.

## Privilege and limit audit — 2026-10-08

| Surface | Finding before this change | Remediation in the new migration |
|---|---|---|
| `check_restaurant_limits()` | `NEW.source = 'seed'` skipped counting; caller could backdate `NEW.created_at`; system columns could be spoofed. | Removed client-controlled bypass. Derives source from `auth.uid()`, canonicalizes `created_at`, status and counters, pins `created_by` to authenticated actor and counts that actor's rows. Trusted null-UID seed/admin inserts remain supported; `anon` has no insert grant. |
| `check_review_limits()` | No caller-column bypass condition, but its daily window relied on writable `created_at`. | Counts by `NEW.user_id` (RLS binds it to `auth.uid()`), while grants and trigger prevent client timestamps. Trigger sets/preserves status, helpful count and timestamps. Trusted null-UID maintenance inserts skip the user limit. |
| Other write-limit functions/triggers | Search of migrations found no other daily user-write limit trigger/function. `restaurants_in_bounds()` also accepted unbounded `lim` and had no stable order. | Bounds RPC clamps to 0–500 and orders by `r.id`. |
| `restaurants` | Table-level grants exposed source, status, counters and created_at. | Revoke table INSERT/UPDATE; allow only `name`, `address`, `province`, `location`, `created_by`. |
| `reviews` | Table-level grants exposed `helpful_count`, `status`, `created_at`, `updated_at`. | Revoke table INSERT/UPDATE; allow user review columns only and canonicalize system fields in a trigger. |
| `reports` | Table-level grants exposed status and created_at. | Revoke table INSERT/UPDATE; allow user report fields on insert and reason on update; trigger owns status/timestamp. |
| `review_photos` | Table-level writes included generated id and all row fields. | Revoke table INSERT/UPDATE; grant selected insert/update columns. |
| `saved_items` | Table-level writes exposed created_at. | Revoke table INSERT/UPDATE; grant user fields only and canonicalize created_at. |
| `blocks` | Table-level writes exposed key columns; there is no separate system metadata. | Revoke table INSERT/UPDATE; allow key-column inserts only. |

## New regression coverage

- `supabase/tests/05_security_privileges_test.sql`: 24 pgTAP assertions. Exploit attempts and privilege checks run as `authenticated`; setup/default inspection uses database owner. Covers `source='seed'`, backdated restaurants/reviews, forged restaurant metadata and system columns on the named tables.
- `supabase/tests/06_map_bounds_security_test.sql`: 4 pgTAP assertions under `anon`; creates 501 fixtures and checks the cap, stable ordering, negative limit and execute grant.
- Tests-first commit `5cf329f` is pushed to `security/m3-privilege-tests-first` before the hardening migration. The private Actions API returned 404 without credentials, `gh` is unavailable, and Docker daemon is stopped, so its database test result could not be collected locally. GitHub's push response suggested [creating its PR](https://github.com/HienIT1210/Food-map/pull/new/security/m3-privilege-tests-first).
- Deliberate mutation commit `7becc17` is pushed to the separate `security/m3-privilege-mutation` branch and is under [PR #4](https://github.com/HienIT1210/Food-map/pull/4); it restores table-level restaurant INSERT/UPDATE privileges. The user confirmed main commit `4739d74` was green before opening the PR. The user-provided mutation CI log reports `Files=6, Tests=77, Result: FAIL`: `01_rls_test.sql` fails T23 because UPDATE no longer raises `42501` under the restored grant; `05_security_privileges_test.sql` fails R1 and R3-R7 because the broad grant re-enables the prohibited writes. R2 receives the trigger's `P0001` daily-limit error instead of the expected privilege error `42501`; this is also an assertion failure on the mutated branch, while the trigger still enforces the limit. This red result is expected for the intentional regression branch. Do not merge PR #4; do not apply the mutation or run `db push`.

Run `supabase test db` on CI or with the local Supabase Docker stack running. No `supabase db push` was run; migration `20261008100000_harden_user_write_privileges.sql` remains unapplied to cloud.

## pgTAP fixture rules

- Every SQL test file must own its fixtures in `begin; ... rollback;`, declare `plan(N)`, and keep the assertion count aligned with that plan. Keep fixture UUID ranges distinct between files.
- `auth.users` INSERT fires `public.handle_new_user()` and creates a matching `public.profiles` row. If a test also prepares that profile, use `ON CONFLICT (id) DO UPDATE` instead of a plain INSERT.
- Database-owner fixture setup must set both `role = postgres` and `request.jwt.claims = '{}'` before inserts when the trigger uses `auth.uid()`. Changing `current_user` does not clear JWT claims; a stale user claim still makes security-definer triggers treat setup rows as that user.
- Seed restaurant INSERTs are canonicalized by the security trigger (including `avg_rating = 0`). Tests that need controlled ratings must update fixture rows as `postgres` inside their test transaction; do not weaken the trigger.
- Distinguish privilege denial from RLS filtering: when a role lacks the needed table/column privilege, assert SQLSTATE `42501` with `throws_ok`, then read back as a privileged role to prove the row stayed unchanged. Expect zero affected rows only where the role has the required SQL privilege and the applicable RLS policy filters the target row.

## CI fixture fixes — 2026-10-08

- `01_rls_test.sql`: the privileged fixture block ran with `role = postgres`, but retained User B's JWT claims. Security-definer triggers still saw `auth.uid() = User B`, attributed the generated restaurants to that user and hit the five-per-day cap. The setup now clears `request.jwt.claims` under `postgres`; the existing authenticated limit checks remain unchanged.
- `04_map_filter_test.sql`: the restaurant insert trigger deliberately resets seed `avg_rating` to 0. The test now sets eight seed ratings to 4.8 and the rest to 3.5 in a privileged UPDATE inside its transaction; the `min_rating` assertion remains unchanged.
- `05_security_privileges_test.sql`: inserting fixture users fires `handle_new_user()` and creates profiles. The explicit profile fixture insert now uses `ON CONFLICT (id) DO UPDATE`.
- Audited all six SQL tests: each starts `begin;`, ends `rollback;`, and contains one unchanged plan. Plans total 77 assertions; literal fixture IDs are distinct across files (excluding the shared all-zero Auth `instance_id`).
- Follow-up CI fix: `01_rls_test.sql` T23 previously ran a bare `UPDATE public.restaurants` and expected the subsequent readbacks to show no changes. The hardening migration correctly removed UPDATE privilege on system-managed columns, so PostgreSQL raises `42501` before RLS can filter rows. T23 now asserts that error with `throws_ok`; T24/T25 read back counters and status under `postgres`. The three assertions and `plan(38)` are preserved. The earlier T5 review UPDATE/DELETE remain row-filter checks: their SQL privileges are present and RLS policies exclude another user's target row.

## M4 public read and anonymous review privacy

- `supabase/tests/07_m4_anon_read_test.sql` runs the `search_restaurants`, `restaurant_detail`, and `public_reviews` assertions after switching to `role anon` and narrowing the session search path to `public`. It verifies accent-insensitive and typo-tolerant dish search, restaurant-name/address search, explicit anon execution, and that an anonymous public review has a null `author_id` while the view has no `user_id` column. It declares `plan(8)` and wraps all fixtures in `begin; ... rollback;` with the dedicated `a404...` UUID range.
- `src/features/reviews/public-review-privacy.test.tsx` checks the rendered anonymous label, absence of profile links/IDs, the PostgREST request targeting only `public_reviews` with an explicit safe-column selection, and a simulated network response without `user_id`. The response schema is strict, so an unexpected field such as `user_id` is rejected.
- CI database expected after M4 migration: seven SQL test files and 85 planned assertions (previous 77 plus M4's 8). Docker was unavailable locally; collect CI output before treating the DB checks as green. Do not run `db push` until the user chooses to apply the new M4 migration.

## M5 review writes: regression changes and pending mutation check — 2026-10-09

### What M5 changed for existing tests

M5 revoked `INSERT`, `UPDATE` and `DELETE` on `public.reviews`, `public.review_photos` and `public.review_helpful` from `public`, `anon` and `authenticated`, and granted `EXECUTE` only on the ownership-checked RPCs. Every write test that used a direct table write therefore had to be re-pointed at the RPC, without weakening any security expectation.

| Test | Before | After | Why the property still holds |
|---|---|---|---|
| `01` T8 | Direct review INSERT → `P0001` daily-limit trigger | Direct review INSERT → `42501` | The write is denied earlier (no table privilege). The limit itself now lives behind `save_review`; `08` proves an eleventh review is refused by the RPC. |
| `01` T20, T22, T33 | Direct INSERT as another user / `anon` / banned user → `42501` | Unchanged expectation `42501` | Same SQLSTATE; the denial is now privilege-based rather than policy-based. Spoofed ownership is impossible because `save_review` never accepts a `user_id`. |
| `01` T34 | `lives_ok` direct INSERT of a non-identifying path as `authenticated` | `lives_ok` `add_review_photo(...)` as the review owner | The only legitimate write path. Still proves a non-identifying path is accepted. |
| `01` T35, T37 | `throws_ok 23514` as `authenticated` | Same assertion run as database owner | The `BEFORE` triggers only remain reachable on privileged maintenance writes; running them as owner tests the rule itself instead of the privilege wall. |
| `01` T36 (old) | `authenticated` could insert an anonymous-review photo | `01` T36 accepts the review-UUID path as owner; `01` T38 asserts direct metadata INSERT → `42501` | Split into "the rule still permits the safe shape" plus "the API roles cannot bypass the RPC". |
| `05` R20 | `authenticated` held column-level INSERT on `review_photos` | `authenticated` holds no table write on `review_photos` but holds `EXECUTE` on `add_review_photo` | Inverts the assertion to the M5 contract while keeping the same slot and the same "only these columns" intent. |
| `05` R23 | `authenticated` held column-level INSERT on `reviews` | `authenticated` holds no table write on `reviews` but holds `EXECUTE` on `save_review` | Same as above. |

`plan(43)` in `01`, `plan(24)` in `05`, `plan(14)` in `08` and `plan(15)` in `09`. No test was deleted or commented out.

**Fifth CI run (commit `4f69873`+, `09` only) — plan was simply wrong:** `09` declared `plan(16)` but contains **15** assertion calls, and its labels ran `M5-02 … M5-16` with no `M5-01` anywhere in the repository. Both defects are original to commit `342c08c`, which created the file with **14** assertion calls while declaring `plan(16)`; `git log -p` shows only additions and the one label split, so no test was ever deleted, merged away, or hidden in a block that does not run. The labels are now sequential `M5-01 … M5-15` and the plan is `15`, which is the assertion count — not a lowered expectation: every rule tested before is still tested. The assertion count is verified mechanically (a parser that walks balanced parentheses), not by eye.

**M5 rule coverage after renumbering** (`docs/PROGRESS.md` §5.1 rules 1–12 plus the photo-path contract, all covered):

| Rule | Assertion |
|---|---|
| 1. `check_review_limits` 10/24h via `auth.uid()` | `01` T8 (`P0001` from `save_review`) |
| 2. `save_review` validation + anonymous age/email | `09` M5-04, M5-05, M5-06 |
| 3. `delete_review` ownership + returned paths | `08` tests 13–14 |
| 4. `my_review_for_target` / `my_reviews` scope | `08` my_reviews assertion; `09` M5-03 |
| 5. `toggle_review_helpful` one vote, no self-vote | `09` M5-13, M5-14, M5-15 |
| 6. `add_review_photo` ownership + path contract | `01` T34–T37, T38; `08` sixth-photo rejection |
| 7. write grants revoked, RPC execute only | `09` M5-01, M5-02, M5-03; `05` R20, R23 |
| 8. storage bucket size/type/policies | migration-level; asserted through M5-01–M5-03 privileges |
| 9. photo cap of five | `09` M5-12 |
| 10. restaurant `avg_rating`/`review_count` recompute | `01` T24/T25 (before/after snapshot) |
| 11. `helpful_count` recompute from votes | `09` M5-15 |
| 12. system fields enforced | `09` M5-09, M5-11; `05` R11–R15 |

**RLS read-back rule (add to the fixture rules):** a read-back that must observe **another user's** row has to run as the database owner. Under `authenticated`, RLS turns the value into "no row", and an unguarded subquery then yields NULL rather than a comparable value — which pgTAP treats as a hard failure, not a soft one.

**Design confirmation — a voter seeing zero `public.reviews` rows is intentional, not a misconfigured policy.** `docs/SPEC.md` line 320 requires exactly this: *"`reviews`: client không SELECT trực tiếp người khác. Chủ sở hữu có thể SELECT/UPDATE/DELETE review của chính mình"*, and line 321 adds *"Người dùng công khai chỉ đọc review qua view `public_reviews`"*. The mechanism is the `reviews` SELECT policy `using (auth.uid() = user_id)` created in `20261004114000_init_schema.sql`, which carries the source comment *"Client KHÔNG THỂ select trực tiếp review của người khác (dùng view public_reviews)"*; the public view is granted `select` to `anon, authenticated`. Reading another user's `helpful_count` straight from the table must therefore return no row — the count is read through `public_reviews` (which exposes `helpful_count`) or as the database owner. Tests must not treat the empty result as a bug, and must not widen the policy to make a read-back "work".

**Third CI run (commit `4f69873`, Files=9, Tests=118) — three residual defects, all test-side:**

| Symptom | Cause | Fix |
|---|---|---|
| `01` T24 `avg_rating and review_count remain unchanged` = false | The assertion compares against the fixed 0/0 baseline, but nothing printed the row's state before the RPC-based tests ran, so the run could not show whether T8/T20/T22 or T23 moved it. | `diag()` before T8/T20/T22, after the T8 RPC, after T9 and after T23 print `avg_rating`, `review_count` and the number of reviews for restaurant 444. Expected values stay 0/0. |
| `08` planned 13 but ran 14 | The previous round replaced `is(delete_review(...), true)` with `lives_ok(...)` **and** added a `review_photos` count read-back, i.e. one assertion more. | `plan(14)`; the file now lists which two assertions those are and why each is correct on its own (owner delete succeeds; the cascade removes the metadata rows). |
| `09` M5-15 returned NULL and the file stopped at 14/16 | The counter was read as `authenticated`, and the `reviews` RLS policy only exposes rows owned by `auth.uid()`. Reading another user's review therefore returns **no row**, so `toggle(...) and (select helpful_count ...) = 1` collapses to NULL. `pgTAP`'s strict `finish(true)` then aborts the file before M5-16 (the null-`author_id` assertion) runs. | Split into `lives_ok` for the vote and a separate `M5-16` read-back under `postgres`; `diag()` prints the review row, `current_user`, `auth.uid()` and the visible row count before and after. |

**Fourth CI run (commit `59af17c`, Files=9, Tests=119) — two residual defects:**

| Symptom | Cause established by the run | Fix |
|---|---|---|
| `01` T24 `remain unchanged` = false | The expectation was the literal `0/0`, but the diagnostics printed `avg_rating=4.50 review_count=2` at **every** checkpoint (before T8, after the T8 RPC, after T9, after T23). Restaurant `dddd4444-…444` owns exactly two visible fixture reviews (rating 5 from User A and the anonymous User B review of rating 4), and the M5 `recalculate_restaurant_review_stats` trigger averages them to `4.50`. The trigger is new in M5, which is why the older `0/0` expectation used to hold; T8/T20/T22/T23 never moved the value. | T24/T25 now compare against a temp-table snapshot taken immediately before the denied UPDATE, which itself tries to write `1.00 / 99 / closed`. The invariant "the denied UPDATE changes nothing" is proven by before/after equality, with no invented constant. |
| `09` still 15 of `plan(16)` | The combined expression `is(toggle_review_helpful(...) and (select helpful_count …) = 1, true)` is what aborted the file: the read ran as `authenticated`, RLS hides another user's row, so the comparison became NULL and pgTAP's strict `finish(true)` treated it as fatal. | The vote and the derived counter are now two independent assertions: `lives_ok` for the vote, then a `postgres` read-back of `helpful_count`. A `diag()` prints the vote-table row count and a marker immediately before `finish()` so the next run shows which assertion stops counting, if any. |

**Invariant lesson (add to the fixture rules):** when a fixture legitimately produces derived values (here `avg_rating`/`review_count` from a stats trigger), an assertion must compare **before and after**, never against a constant chosen by hand. A hard-coded expectation silently encodes "the trigger did not run", which is the opposite of what the milestone requires.

**RLS read-back rule (add to the fixture rules):** a read-back that must observe **another user's** row has to run as the database owner. Under `authenticated`, RLS turns the value into "no row", and an unguarded subquery then yields NULL rather than a comparable value — which pgTAP treats as a hard failure, not a soft one.

**Why `01` moved from `plan(38)` to `plan(43)` (CI run 1 evidence):** the first M5 CI run stopped at `01_rls_test.sql` line 102 with `permission denied for table reviews`. That line was a **bare** `UPDATE` (and the next line a bare `DELETE`) whose comment claimed RLS would silently match zero rows. M5 revoked the table-level write grants, so those statements now raise `42501` and, being unasserted, they aborted the whole file at 6/38. Every such write must therefore become its own `throws_ok(..., '42501')` slot, which is five assertions more than the old bare statements consumed (T5 split into `T5a`/`T5b`, plus the `T8`, `T23` and `T38` denials that used to be unasserted or asserted only through read-backs). The plan number is the only thing that changed; T1-T38 still cover the same rules. `diag()` calls print the live `save_review`, `add_review_photo` and `delete_review` signatures so a mismatch is never a bare `42883`.

**Signature defect found by the same run:** `save_review(p_rating smallint)` and `add_review_photo(p_position smallint)` could not be called with a bare `5`; PostgreSQL reported `function public.save_review(unknown, unknown, integer, unknown, boolean) does not exist` (42883). PostgREST sends a bare JSON number as `integer` ([Functions as RPC](https://postgrest.org/en/stable/references/api/functions.html)), so this was an app-breaking defect, not only a test defect. The migration now declares both parameters as `integer` (the `1..5` range check and the implicit `smallint` column cast stay in place) and the tests call them without casts.

**Deletion redesign:** `delete_review` no longer `delete from storage.objects`. Supabase Storage blocks direct SQL deletes on that table and the old statement left orphaned files. The RPC now deletes only the review row and returns `table (deleted_review_id uuid, storage_paths text[])`; the caller removes the files through the Storage API. `08` now asserts that the RPC succeeds and that the photo metadata rows cascade. No test expects SQL to remove a `storage.objects` row.

### New coverage

`supabase/tests/09_m5_review_rules_test.sql` — `plan(16)`, fixtures in the `a909...` UUID range:

- `M5-02`/`M5-03`/`M5-04`: `anon` cannot execute the write RPCs; `authenticated` holds no table write on the three review tables but holds `EXECUTE` on all five RPCs.
- `M5-05`/`M5-06`/`M5-07`: anonymous posting requires a verified email and a profile at least 24 hours old — refused for a young account, refused for an unverified account, allowed for an eligible one.
- `M5-08`/`M5-09`: the anonymous review is visible through `public_reviews` with a null `author_id`.
- `M5-10`/`M5-11`/`M5-12`: saving the same (user, restaurant, dish) target returns the same UUID, leaves exactly one row, and updates the rating in place.
- `M5-13`: a sixth photo for one review is rejected by the server (`P0001`).
- `M5-14`/`M5-15`: a review owner cannot vote their own review helpful, and a vote by another user derives `helpful_count` from the vote table rather than a client-supplied value.

### Mutation check for the new M5 rule (pending CI evidence)

The rule to attack: **API roles must not be able to write review data outside the ownership-checked RPCs, and anonymous review photos must not carry the owner UUID.**

Branch note: the first mutation branch `test/m5-write-rule-mutation` (`fedf3af`) was created from `076b3d2` and is now **stale** — it contains the `smallint` signatures and the SQL `storage.objects` delete. Delete it (`git push origin --delete test/m5-write-rule-mutation`) and recreate the branch from the green `main` before running any mutation. No PR was opened for it.

Mutation plan (one mutation at a time, on a temporary branch, PR never merged):

1. Re-grant table-level `INSERT, UPDATE, DELETE ON public.reviews, public.review_photos, public.review_helpful TO authenticated` at the end of the M5 migration. Expected red: `05` R20 and R23, `09` M5-03, and `08`'s "review inserts must go through the validated RPC" / "review photo metadata writes must use the ownership-checked RPC".
2. Change `save_review.p_rating` and `add_review_photo.p_position` back to `smallint`. Expected red: `08` and `09` fail hard with `42883`, which is exactly the defect this round fixed — a useful regression tripwire for the PostgREST boundary.
3. Weaken `add_review_photo`'s path check to `true`. Expected red: `01` T35 (the blacklist trigger still catches the owner UUID, proving it is a backstop, not the primary control).
4. Replace `delete_review`'s `returns table (deleted_review_id uuid, storage_paths text[])` with the old boolean signature that deleted `storage.objects`. Expected red: the `repository.ts` contract and `08`'s "review owner can delete their review through the RPC" / photo-cascade assertions.

Record the TAP test names and the failing lines here once CI reports them. Do not merge the mutation PR; delete the branch afterwards.

## pgTAP search_path regression rule — 2026-10-09

- A test query that runs with `search_path = public` must be executed separately and its result stored (for example, in a temporary table). Restore `search_path = public, extensions` immediately before invoking **any** pgTAP function. Schema-qualifying `extensions.ok()` is not enough: pgTAP's internal `_todo()` resolution uses the caller's search path, which caused `function _todo() does not exist` in `07_m4_anon_read_test.sql`.
- Audit of SQL tests 01–07: 01 and 02 already isolate the public-only statement and restore the extension path before assertions; 03–06 never narrow the path; 07 was incorrect and now stores anon query results before restoring the path. Keep all plan counts and assertions intact.
- Regression reproduction in CI: `01_rls_test.sql` creates fixture `dddd4444-4444-4444-4444-444444444444` named `Test Phở` and runs `select id from public.search_restaurants('pho bo', 50) where id = 'dddd4444-4444-4444-4444-444444444444';` as T6/T11 inside its test transaction. The transaction ends with `ROLLBACK`, so running that SELECT by itself in Cloud SQL Editor after `db push` returns no rows simply because the fixture is absent; it does not reproduce the function result. To test after push, create the fixture and run the query in one transaction, then roll back:

```sql
begin;
insert into public.restaurants (id, name, location)
values (
  'b4050000-0000-4000-8000-000000000001',
  'Test Phở',
  extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326)
);
select id
from public.search_restaurants('pho bo', 50)
where id = 'b4050000-0000-4000-8000-000000000001';
rollback;
```

- CI diagnostics for commit `b1dc6e7` establish the actual cause: `pho bo` has 21 unique matches after grouping/final restaurant join; with `lim=10`, 10 rows are returned and `Test Phở` is position 11. With `lim=50`, 21 rows are returned and the fixture is present. The ten `Quán Phở N` seed restaurants have an exact `Phở Bò` dish match (relevance 1), so they correctly rank before the name-only `Test Phở` result (relevance 0.5). The function and product ranking are correct; T6/T11 had an artificially small limit. Both assertions now use `lim=50`, retaining the requirement that accentless `pho bo` returns the restaurant named `Test Phở`. Removed the unneeded candidate-rewrite migration and all temporary SQL diagnostics; `plan(38)` remains unchanged.

## M4 top-N regression diagnostic — 2026-10-09

- `supabase/seed.sql` contains dish `Phở Bò`, linked to restaurant `Phở Hòa Pasteur`. CI applies `supabase/seed-cloud.sql` afterward; that file deletes prior `source='seed'` restaurants/dishes/categories and replaces them with 30 restaurants. It links dish `Phở Bò` to the ten restaurant names `Quán Phở 3`, `Quán Phở 6`, `Quán Phở 9`, `Quán Phở 12`, `Quán Phở 15`, `Quán Phở 18`, `Quán Phở 21`, `Quán Phở 24`, `Quán Phở 27`, and `Quán Phở 30`.
- Test 01 adds `Test Phở` without a dish. Test 07 has a separate transaction fixture `Quán M4 Search Fixture` with dish `Phở bò M4`; it is rolled back and does not coexist with test 01. Test 03 only asserts the cloud seed counts; test 04 uses the cloud-seed fixtures and adds no pho restaurant/dish; test 02, 05, and 06 add no pho search fixtures.
- Runtime `diag()` confirmed the displacement: 34 raw match rows, 21 unique matches, 21 rows after the final restaurant join, 10 after `lim=10`, and 21 after `lim=50`; `Test Phở` ranks 11th. The ten seed restaurants selling the exact queried dish rank above a restaurant whose name contains only the first token. Keep this product ordering: an exact dish match should outrank a partial restaurant-name match. T6/T11 now pass `lim=50`, and still assert that `pho bo` finds the name-only `Test Phở` result. Temporary diagnostics have been removed.
