# Before: the branch GEOxyz runs today, on Redmine 5.1

`master` @ a0865eb on Redmine 5.1.13 (5.1-stable, Ruby 3.2.6, PostgreSQL 16), production mode,
the same scenarios and seed as `docs/e2e/` (run 2026-10-06, `RMP_E2E_OUT=docs/e2e/before`).

The captions describe the behaviour after the migration; the "Problems" section of each
`<scenario>.md` lists where the old version differs. In short:

- save.md: a user with the permission in e2e-project changed an issue of e2e-private, which he
  cannot see (`save-editor-private-refused.png` shows the accepted request: back on the list);
  a forged author_id and closed_on were written; no "Successful update."; no history entry.
- edit-form.md: the parent's derived dates and % done were inputs; the workflow read-only custom
  field was an empty cell.
- context-menu.md: enabled "Edit Inline" for a member without the permission (it led to a 403).
- grouping.md: the totals rows carried the `group` class (6 "groups" for 3); no SVG icons is
  expected on 5.1 (they are Redmine 6+).
