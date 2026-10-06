# Redmine 7 migration: redmine_inline_edit_issues

Start a Claude Code (or Codex) session on this repository, branch `redmine70-migration`, with:

> Read CLAUDE.md and docs/REDMINE7-MIGRATION.md, then carry out the Redmine 7 migration of this
> plugin as described there, on branch redmine70-migration. That includes the plugin's tests on
> PostgreSQL and MariaDB, every function exercised end to end on a real running Redmine in a
> browser (with and without permissions, failure paths included) with screenshots you looked at,
> and an OpenAI review of the diff when OPENAI_API_KEY is set. Report to me in Dutch at the end.

This file is the plan and the memory of that work. Update it as you go: verdicts, results,
what is left. Written 2026-10-06 from a measured analysis (report at the bottom).

## Status

| | |
|---|---|
| Plugin id | `redmine_inline_edit_issues` |
| GEOxyz runs today | `master` |
| Upstream | omegacodepl/redmine_inline_edit_issues master @ 2cf2f6c (2021-03-01) |
| Runs on Redmine 7 as is | JA |
| Upstream sync | UPSTREAM DOOD |
| After sync | n.v.t. |
| Complexity (1 trivial .. 5 rewrite) | 2 |
| Measured on | Redmine 7.0.1 (7.0-stable-GEOxyz + latest 7.0-stable), Rails 8.1.3.1, Ruby 3.3.6, PostgreSQL 16 and MariaDB 10.11 |
| Branch head when this file was written | `f4db0ae` |

## Already on this branch

- nothing: the branch equals the branch GEOxyz runs today.

## Work list for the migration session

In this order: things that break, security, the GEOxyz changes, the open items, then the checks.

**Priority items**

1. SECURITY (fix in this migration): update_multiple updates any issue id from params with `to_unsafe_hash`. Load the issues through Issue.visible and the authorized ids, check `editable?` per issue, assign through `safe_attributes=` with `init_journal`, so workflow field permissions and redmine_editauthor's author permission apply.
2. Repair the 5 functional tests so they prove something (syntax, setup, the `assert_response 999`).

**Open items from the analysis** (Dutch; where they repeat a priority item, the priority item wins)

3. SECURITY (pre-existing, upstream since v1.0.0): update_multiple updates any issue id in params with to_unsafe_hash, no visibility/safe_attributes/workflow check; demonstrated: a non-member changed subject and author_id of an issue in a private project. Fix with Issue.visible + editable? + safe_attributes=
4. Repair the 5 functional tests (old request syntax, permission setup, assert_response 999)
5. Deface override in config/initializers is never loaded (5.1 and 7.0): load from init.rb or drop deface from PluginGemfile
6. Cosmetic: no SVG icons on context menu item, group expander, option links

**Checks**

7. Run the plugin's whole test suite on Redmine 7.0-stable-GEOxyz with PostgreSQL AND MariaDB, and once on 5.1-stable if the branch is meant to stay 5.1-compatible.
8. Check Redmine 7 webhooks against this plugin (see "Rules"), and note the result here even if nothing is needed.
9. Verify every feature of the plugin by hand on a running Redmine 7 (screenshots).

## GEOxyz changes to review or re-apply

These GEOxyz commits are on the branch GEOxyz runs today and therefore on this branch. Review each one against the code it now sits on (upstream merges and Redmine 7 core): drop it if upstream or core now does the same, rewrite it if it is not up to the quality rules below (tests, I18n, security, portability), keep it otherwise. Record the verdict per commit in this file.

| commit | date | subject |
|---|---|---|
| `a0865eb` | 2025-08-31 | Support for the Redmine ITIL Priority plugin |
| `b365a80` | 2025-06-29 | Feature: add depending list and keyed list #6103 |
| `72342eb` | 2025-06-19 | Defect: inline edit does not handle user or extended_user custom fields well |
| `46d01a2` | 2025-06-18 | Defect: inline edit sorting fails when on navigation #6103 |
| `fecb853` | 2025-04-26 | * Resolve compatibility issues * Partially resolve some issues * Still to be further tested, as some issues remain. |

## After the upgrade (production)

Actions the person doing the upgrade must take, or know about, for this plugin:

- None known. Add here what the session finds.

## How to test

```sh
./.codex/redmine_clone.sh 7.0-stable-GEOxyz      # or 5.1-stable / 6.1-stable / 7.0-stable
./.codex/test_setup.sh                                 # RMP_DB=mariadb for MariaDB, RMP_PROVISION_DB=0 if a server runs
./.codex/test_plugin.sh                                # minitest + rspec of this plugin
```

```sh
./.codex/start_server.sh       # real Redmine (production mode) with this plugin, seeded users and projects
./.codex/e2e.sh                # browser: smoke over the plugin's pages, core issue flows, test/e2e/*.mjs
./.codex/openai_review.sh      # independent OpenAI review of the diff, only when OPENAI_API_KEY is set
```
Write one scenario per function in `test/e2e/<function>.mjs` (example at the top of
`.codex/e2e/lib.mjs`); screenshots and a table per scenario land in `docs/e2e/`. Users:
`admin`, `manager` (every permission), `reporter` (no plugin permissions), `outsider` (no
membership); password `Redmine7Test!`. Needs Node with Playwright and Chromium
(`npm install -g playwright && npx playwright install --with-deps chromium`).

On GitHub the same runs by hand only: Actions > "Redmine tests (manual)" > Run workflow (tick
"e2e" for the browser run; screenshots come back as an artifact).

The coordinator's harness (`plugin-check.sh` in the migration kit, kept outside this repo) adds a
browser smoke test of every page the plugin adds and runs all GEOxyz plugins together; the
results quoted in the analysis come from it.

## How the migration session works (same for every plugin)

1. **Start**: `git fetch && git checkout redmine70-migration && git pull`. Read this whole file,
   including the analysis report at the bottom. Do not reopen decisions recorded here.
2. **Baseline, before you change anything**:
   - the plugin's tests on Redmine 7.0-stable-GEOxyz with PostgreSQL and with MariaDB;
   - a real running Redmine with this plugin (`./.codex/start_server.sh`) and the browser run
     (`./.codex/e2e.sh`: smoke over every page the plugin adds, plus the core issue flows).
   Write the numbers here. Something already broken now is a finding, not your regression.
3. **Inventory of functions**: list every function of the plugin in this file, in a table
   "function | how a user reaches it | scenario | screenshot". Take them from the README,
   `init.rb` (permissions, menus, settings, project modules), routes, hooks and view
   overrides, macros, mail handling, API endpoints, rake tasks and cron jobs. This table is the
   coverage list for step 8; a function that is not in it will not be tested.
4. **GEOxyz changes**: go through the table above, one item at a time. Each kept or re-made change
   is its own commit with a test that proves it. Record the verdict in the table.
5. **Work list**: then the numbered list, in order. One concern per commit.
6. **Portability**: everything must run on Redmine's supported databases (PostgreSQL,
   MySQL/MariaDB; SQLite where the plugin already supports it). Migrations must be reversible and
   are run down and up on PostgreSQL and MariaDB.
7. **Together**: run with the other GEOxyz plugins installed (the migration kit's harness, or
   `RMP_EXTRA_PLUGINS`). A failure that only appears in combination is a finding to record here.
8. **End to end, visually, every function**: on the real Redmine from `start_server.sh`
   (production mode, the way GEOxyz runs it), write one scenario per function in
   `test/e2e/<function>.mjs` with `.codex/e2e/lib.mjs` and run them with `./.codex/e2e.sh`.
   - Each function as the users that matter: `admin`, `manager` (every permission, the
     plugin's included), `reporter` (member without the plugin's permissions), `outsider`
     (no membership, private project must stay invisible).
   - The failure paths too: setting off, permission absent, empty state, invalid input, the
     value that used to raise. A refusal that is shown is evidence as much as a success.
   - One screenshot per function and per path, with a caption saying what it proves. Open
     every screenshot and look at it: a picture nobody looked at proves nothing. Commit them
     in `docs/e2e/` and list them in the inventory table.
   - Functions without a page (mail in and out, REST API, rake tasks, cron, webhooks): exercise
     them against the same running instance (mails land in `redmine/tmp/mails`, `t.mails()`
     reads them; API through `t.page.request`) and record command and result.
   - Before pictures where behaviour or layout changes: the branch GEOxyz runs today, on
     Redmine 5.1, same scenarios, `RMP_E2E_OUT=docs/e2e/before`.
   - Run the whole e2e set once on MariaDB as well (`RMP_DB=mariadb`, then `start_server.sh --reset`).
9. **Independent review**: first your own, adversarial: re-read the whole diff as if someone
   else wrote it and you are paid to reject it. Then, **when `OPENAI_API_KEY` is set in the
   session**, `./.codex/openai_review.sh`: it sends the diff of this branch to an OpenAI model
   and writes `docs/reviews/openai-<date>-<sha>.md`. Every finding gets a `Resolution:` line
   there (fixed in <commit>, with a test, or why not). Fix, re-run the tests and the e2e set,
   and run the review again until it has nothing new that you accept. Without the key: write
   "OpenAI review: skipped, no OPENAI_API_KEY" in the report; never send code anywhere else.
10. **After the upgrade**: anything the production upgrade must do for this plugin (data fixes,
    settings, cron, files, removed features) goes into the section "After the upgrade".
11. **Finish**: update "Status", the inventory and the work list in this file, push
    `redmine70-migration`, and report: what changed, test numbers on both databases, e2e
    numbers (scenarios, screenshots, problems), the review result, what is left, what needs Jan.

### Stop and ask Jan when
- a GEOxyz change would be lost or behave differently for users;
- a new gem, a new setting with user impact, or a schema change not required by Redmine 7 seems needed;
- the change would send data to an external service (the OpenAI review of the code diff is the
  one exception Jan approved, and only when the key is present);
- upstream and GEOxyz disagree on behaviour and both are defensible.

## Rules

- **Target**: Redmine 7.0-stable-GEOxyz (https://github.com/jcatrysse/redmine), Rails 8.1, Ruby 3.3+.
  Core sources for comparison: branches `5.1-stable`, `6.1-stable`, `7.0-stable`, `7.0-stable-GEOxyz`.
- **Evidence**: never report a test, lint, browser check or review as passed without having seen
  it. Quote the summary lines; list the screenshots. "Should work" is not a result, and a green
  test suite is not proof that a feature works in the browser.
- **Tests**: never skip, delete or weaken a test. A test that encodes Redmine 5 markup or
  behaviour is updated to Redmine 7, with the reason in the commit. Every fix gets a test that
  fails without it.
- **Minimal diffs** in the plugin's own style. No reformatting, no unrelated refactoring.
  Something wrong elsewhere: write it down here, do not fix it in passing.
- **Security**: authorization on every action and entry point; `safe_attributes`, never
  `to_unsafe_hash` into `update`; no SQL built from params; no secrets in logs; no `html_safe` on
  user input.
- **Webhooks (new in Redmine 7)**: core sends issue payloads (core `issues/show.api.rsb`, rendered
  as the webhook owner) to webhook endpoints, past plugin hooks and controller patches. If the
  plugin hides, adds or changes issue data, make webhooks consistent with that or record why not.
- **Redmine 7 conventions**: SVG icons through `sprite_icon` (the `icon icon-*` CSS is gone),
  Propshaft assets under `assets/` (`/assets/plugin_assets/<id>/...`), the new header and user menu,
  `ContextMenus::*Controller`, Loofah-based text formatting, Chart.js as an ES module, sudo mode
  (on by default: `t.sudo()` in a scenario). The breaker list is in the migration kit's CHECKLIST.md.
- **Locales**: keep the locales the plugin ships in sync; translate a new key by matching the
  closest existing key in the same file, not from scratch; do not add new languages.
- **5.1 compatibility**: prefer fixes that also run on Redmine 5.1 so they can be merged early;
  say so when a fix cannot.
- **Git**: work on `redmine70-migration` only; never push to the default branch; never force-push
  a branch someone else uses. Descriptive commit messages (what and why).
- **GitHub Actions**: manual only (`workflow_dispatch`). Do not add push, pull_request or schedule
  triggers.

## Definition of done

- All items of the work list are done or explicitly deferred with a reason, in this file.
- The plugin's tests are green on Redmine 7.0-stable-GEOxyz with PostgreSQL and MariaDB
  (numbers in this file); boot, production-like eager load, migrations up/down OK.
- Every function in the inventory exercised end to end on a real running Redmine, with and
  without permissions and on its failure paths; `./.codex/e2e.sh` green; screenshots looked at,
  committed in `docs/e2e/` and listed.
- Review done: your own, and the OpenAI review when the key is present, every finding resolved
  in `docs/reviews/`.
- No new failure when run together with the other GEOxyz plugins.
- "After the upgrade" lists every action production needs; "Status" is current.


## Analysis report (2026-10-06, Dutch)

# redmine_inline_edit_issues
- Gebruikte branch: master @ a0865eb (2025-08-31) - plugin id redmine_inline_edit_issues, versie 0.0.2
- Upstream: omegacodepl/redmine_inline_edit_issues - upstream HEAD master @ 2cf2f6c (2021-03-01), enige branch
- Fork t.o.v. upstream: 5 eigen commits (compat 2025-04, sortering, user-CF's, depending/keyed lists, ITIL-priority), 0 upstream-commits ontbreken
- Andere relevante branches: geen.
- PluginGemfile: `deface` (1.9.0 in de bundle, boot OK op Rails 8.1). Geen migraties. Tests: 5 functionele tests.

## 1. Werkt out of the box op Redmine 7?   JA (functioneel; tests rood om pre-existing redenen)
- Harness (results/1006-085737-...): OK boot, eager load, migraties, smoke 74/74 (14 plugin-routes; de 404's zijn REST-routes zonder action).
- `FAIL minitest` 5 runs, 1 failure, 3 errors - allemaal pre-existing, faalt identiek op 5.1: 2x pre-Rails-5-syntax `get :edit_multiple, :ids => [...]` (test/functional/inline_issues_controller_test.rb:17,23), 1x 403 i.p.v. 200 (testopzet: permissie/module/members niet geladen, :30), 1x `assert_response(999)` (onzin-assertie, :36). Niet aangepast.
- Live geverifieerd: contextmenu (nu `ContextMenus::IssuesController`, #44169) toont "Inline edit" bij meervoudige selectie (hook `view_issues_context_menu_start` + `@issue_ids`/`@can`/`@project` bestaan nog); /inline_issues/edit_multiple toont 10 rijen met 50 velden; onderwerp wijzigen en opslaan werkt.

## 2. Upstream sync?   UPSTREAM DOOD
- Upstream sinds 2021 stil, fork bevat alles. Alternatieven (commercieel, geen drop-in): RedmineX Inline Edit (claimt 6.1), Redmineflux Inline Editor (6.0).

## 3. Werkt na sync op Redmine 7?   n.v.t.

## 4. Complexiteit en blokkers   score 2 (migratie) - maar zie beveiliging
- Blokkers voor Redmine 7: geen. Branch redmine70-migration = origin/master.
- BEVEILIGING (pre-existing, upstream sinds v1.0.0, niet R7-specifiek, wél dringend):
  - app/controllers/inline_issues_controller.rb `update_multiple`: `Issue.where(id: params[:issues].keys)` zonder zichtbaarheids-/rechtencontrole, en `issue.update(params[:issues][id].to_unsafe_hash)` zonder `safe_attributes`/workflow. `authorize` controleert alleen het meegegeven `project_id`.
  - Live aangetoond: gebruiker `tester` (403 op het issue, geen lid van het private project) wijzigde via `PUT /inline_issues/update_multiple?project_id=geoxyz-verify` het onderwerp **en author_id** van issue #11 in een ander, privaat project.
  - Omzeilt ook workflow-veldrechten (read-only/verplichte velden) en de `edit_issue_author`-regel van redmine_editauthor.
- Stille breuken:
  - De Deface-override (knop in het query-formulier) staat in config/initializers/deface_inline_edit.rb; Redmine laadt plugin-initializers niet (5.1 én 7.0 laden alleen init.rb) -> dode code, `deface` wordt voor niets geladen. Geen regressie.
  - Contextmenu-item, groepsexpander (`icon icon-expanded`) en opties-links (`icon-checked/reload/save`) zonder SVG-icoon in 7.0 - cosmetisch.
  - `before_filter`-tak in de controller is dode code (alleen voor Rails < 5).
- Overlap met Redmine 7 core: geen (core heeft bulk edit, geen inline grid).
- Open werk voor ansif:
  - `update_multiple` dichtzetten: issues ophalen via `Issue.visible` + `editable?`-controle per issue (of `@issues` uit de geautoriseerde ids), en `issue.safe_attributes = ...` (met `init_journal`) i.p.v. `update(to_unsafe_hash)`.
  - Tests herstellen (syntax, testopzet, 999-assertie) zodat ze iets bewijzen.
  - Beslissen of de query-formulierknop (Deface) nog gewenst is; zo ja vanuit init.rb laden, anders `deface` uit PluginGemfile.

## Branch redmine70-migration
- Basis: origin/master @ a0865eb (geen commits nodig)
- Commits: geen
- Eindresultaat harness (results/1006-095352-s3-redmine_inline_edit_issues_redmine70-migration): OK bundle, boot, eager load, migraties dev+test, FAIL minitest 5 runs, 2 assertions, 1 failures, 3 errors (pre-existing), OK smoke 74/74
- Rollback migraties: n.v.t.

