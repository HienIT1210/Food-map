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

## pgTAP search_path regression rule — 2026-10-09

- A test query that runs with `search_path = public` must be executed separately and its result stored (for example, in a temporary table). Restore `search_path = public, extensions` immediately before invoking **any** pgTAP function. Schema-qualifying `extensions.ok()` is not enough: pgTAP's internal `_todo()` resolution uses the caller's search path, which caused `function _todo() does not exist` in `07_m4_anon_read_test.sql`.
- Audit of SQL tests 01–07: 01 and 02 already isolate the public-only statement and restore the extension path before assertions; 03–06 never narrow the path; 07 was incorrect and now stores anon query results before restoring the path. Keep all plan counts and assertions intact.
- Regression reproduction in CI: `01_rls_test.sql` creates fixture `dddd4444-4444-4444-4444-444444444444` named `Test Phở` and runs `select id from public.search_restaurants('pho bo', 10) where id = 'dddd4444-4444-4444-4444-444444444444';` as T6/T11 inside its test transaction. The transaction ends with `ROLLBACK`, so running that SELECT by itself in Cloud SQL Editor after `db push` returns no rows simply because the fixture is absent; it does not reproduce the function result. To test after push, create the fixture and run the query in one transaction, then roll back:

```sql
begin;
insert into public.restaurants (id, name, location)
values (
  'b4050000-0000-4000-8000-000000000001',
  'Test Phở',
  extensions.st_setsrid(extensions.st_makepoint(105.8, 21.0), 4326)
);
select id
from public.search_restaurants('pho bo', 10)
where id = 'b4050000-0000-4000-8000-000000000001';
rollback;
```

- CI diagnostics for `01` show the fixture is `active`, normalizes to `test pho`, the query to `pho bo`, the `pho` token predicate is true, similarity is `0.333`, and the installed function has `search_path=public, extensions`; nevertheless the RPC returns zero. This rules out fixture status, accent normalization, the configured search path, and the similarity threshold as causes. Migration `20261009130000_m4_search_candidate_rewrite.sql` separates restaurant/address and dish candidates, then unions and ranks them. The latest pasted log does not identify its commit; the test now also reports whether that rewrite's `all_matches` CTE is installed and counts the direct restaurant candidate, without adding an assertion or changing `plan(38)`. Those values will distinguish a migration/application mismatch from a failure after candidate selection. T6/T11 remain unchanged; `07_m4_anon_read_test.sql` continues covering accent/typo dish search and restaurant-name search under `anon`.
