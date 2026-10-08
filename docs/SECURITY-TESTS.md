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
- Deliberate mutation commit `7becc17` is pushed to the separate `security/m3-privilege-mutation` branch. It restores the table-wide restaurant write grant and `source='seed'` escape. This is intentionally not merged. Its [PR creation URL](https://github.com/HienIT1210/Food-map/pull/new/security/m3-privilege-mutation) is available, but the PR itself was not created and the expected pgTAP red result was not observed: this environment lacks GitHub API credentials/CLI and local Docker is unavailable. Treat mutation CI evidence as pending.

Run `supabase test db` on CI or with the local Supabase Docker stack running. No `supabase db push` was run; migration `20261008100000_harden_user_write_privileges.sql` remains unapplied to cloud.
