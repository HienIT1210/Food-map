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
| T21 | 3(c) | `anon` reads no rows directly from `reviews` |
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

T5 now checks review UPDATE/DELETE isolation against its own fixture row, so a successful destructive mutation does not affect T8 or T14.

## Repeat the Mutations

Run one mutation at a time on a temporary branch based on the security implementation branch (or `main` after merge):

```powershell
git switch security/m1-security-hardening
git switch -c test/security-mutation-check
```

Apply only the selected mutation in the new migration, commit it, push the branch, and open a PR against the implementation branch. Wait for the `Database (M1+)` job and record the TAP test name and failure lines. Restore the intended migration before the next mutation so each run has one mutation. Do not merge the mutation PR. Close it and delete both the remote and local temporary branch afterward.

For 3(a), broaden the `profiles` UPDATE grant to table-level UPDATE. For 3(b), temporarily use `WITH CHECK (true)` on the review INSERT policy. For 3(c), add permissive `anon` SELECT and INSERT policies on `public.reviews`.

The migration file `20261005100000_security_hardening.sql` is forward-only; after PR #2 is merged, apply it to Supabase Cloud with `npx supabase db push`.