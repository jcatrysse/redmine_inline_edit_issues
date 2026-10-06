// The inline edit form (/inline_issues/edit_multiple): who may open it, what it shows as an
// input and what as text (derived parent values, workflow read-only custom field), custom
// field inputs, sorting by a column header, and the cross-project URL.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('edit-form');

async function issueIds(project) {
  await t.go(`/projects/${project}/issues?set_filter=1&status_id=o&sort=id&per_page=100`);
  return t.page.$$eval('table.issues tr.issue', rows => Object.fromEntries(rows.map(r => [r.querySelector('td.subject').innerText.trim(), r.id.replace('issue-', '')])));
}

await t.login('manager');
const ids = await issueIds(P);
const parent = ids['E2E assigned issue'];
const others = ['E2E unassigned issue', 'E2E related issue', 'E2E subtask'].map(s => ids[s]);
const all = [parent, ...others];
const cols = ['tracker', 'status', 'subject', 'assigned_to', 'start_date', 'due_date', 'done_ratio', 'estimated_hours'];
const cfIds = await (async () => {
  await t.go(`/projects/${P}/issues?set_filter=1&c[]=subject`);
  return t.page.$$eval('#available_c option, #selected_c option', os => Object.fromEntries(os.filter(o => o.value.startsWith('cf_')).map(o => [o.textContent.trim(), o.value])));
})();
const cfCols = ['E2E user', 'E2E list', 'E2E key/value', 'E2E read-only'].map(n => cfIds[n]);
if (cfCols.some(c => !c)) t.problems.push(`custom field columns not found: ${JSON.stringify(cfIds)}`);
const qs = (list, extra = '') => `ids[]=${list.join('&ids[]=')}&set_filter=1&${cols.concat(cfCols).map(c => `c[]=${c}`).join('&')}${extra}`;
const FORM = `/projects/${P}/inline_issues/edit_multiple?${qs(all)}`;

await t.go(FORM);
const rows = await t.page.locator('#inline_edit_form tbody tr.issue').count();
if (rows !== 4) t.problems.push(`manager: ${rows} rows, expected 4`);
// the parent's dates and done ratio are derived from its subtask (core default settings)
for (const f of ['start_date', 'due_date', 'done_ratio']) {
  if (await t.page.locator(`[name="issues[${parent}][${f}]"]`).count()) t.problems.push(`parent: ${f} is an input, but it is derived`);
  if (!(await t.page.locator(`[name="issues[${others[0]}][${f}]"]`).count())) t.problems.push(`leaf: ${f} is not an input`);
}
const ro = cfCols[3].replace('cf_', '');
if (await t.page.locator(`[name="issues[${parent}][custom_field_values][${ro}]"]`).count()) t.problems.push('read-only custom field is an input');
const roText = await t.page.locator(`tr#issue-${parent} td.${cfCols[3]}`).innerText();
if (!/fixed by the workflow/.test(roText)) t.problems.push(`read-only custom field shows "${roText}" instead of its value`);
if (!(await t.page.locator(`select[name="issues[${others[0]}][status_id]"]`).count())) t.problems.push('status is not a select');
for (const [i, kind] of [[0, 'select'], [1, 'select'], [2, 'select']]) {
  const id = cfCols[i].replace('cf_', '');
  if (!(await t.page.locator(`${kind}[name="issues[${others[0]}][custom_field_values][${id}]"]`).count())) t.problems.push(`custom field ${cfCols[i]} has no ${kind}`);
}
await t.shot('manager', 'Manager: every editable field is an input; the parent\'s derived dates and % done and the workflow read-only custom field "E2E read-only" are text');

// sorting by a column header stays on the inline edit form (GEOxyz fix 46d01a2)
await t.page.locator('#inline_edit_form thead th a', { hasText: /^Subject$/ }).first().click();
await t.settle();
t.check('sort by subject');
if (!/inline_issues\/edit_multiple/.test(t.page.url())) t.problems.push(`sorting left the form: ${t.page.url()}`);
const subjects = await t.page.$$eval('#inline_edit_form tbody tr.issue td.subject input', is => is.map(i => i.value));
const sorted = [...subjects].sort((a, b) => a.localeCompare(b));
const desc = [...sorted].reverse();
if (JSON.stringify(subjects) !== JSON.stringify(sorted) && JSON.stringify(subjects) !== JSON.stringify(desc)) t.problems.push(`not sorted by subject: ${subjects}`);
await t.shot('sorted', 'A click on the Subject header sorts the form and stays on it');

// the cross-project URL (selection over several projects)
await t.go(`/inline_issues/edit_multiple?${qs(others)}`);
if (await t.page.locator('#inline_edit_form tbody tr.issue').count() !== 3) t.problems.push('cross-project URL: rows missing');
await t.shot('without-project', 'The form without a project in the URL works for issues the user may edit');

await t.login('developer');
await t.go(FORM, { status: 403 });
await t.shot('developer-refused', 'A member who may edit issues but lacks "Edit inline" is refused (403)');

await t.login('reporter');
await t.go(FORM, { status: 403 });
await t.shot('reporter-refused', 'A member without the plugin\'s permission is refused (403)');

await t.login('outsider');
await t.go(`/projects/e2e-private/inline_issues/edit_multiple`, { status: 403 });
await t.shot('outsider-private-refused', 'A non-member is refused on the private project (403)');

await t.anonymous();
await t.go(FORM);
if (!/\/login/.test(t.page.url())) t.problems.push(`anonymous: not sent to login (${t.page.url()})`);
await t.shot('anonymous-login', 'Anonymous: the form asks to log in first');

await t.done();
