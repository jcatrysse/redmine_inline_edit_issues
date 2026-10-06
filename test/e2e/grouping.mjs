// Grouping on the inline edit form (group_by from the list): group headers with core's SVG
// expander, one group folds, "Collapse all/Expand all" without a JavaScript error (it threw on
// Redmine 7 before this migration), and estimated time totals per group.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('grouping');

await t.login('manager');
await t.go(`/projects/${P}/inline_issues/edit_multiple?set_filter=1&status_id=o&group_by=tracker&c[]=subject&c[]=estimated_hours`);
const groups = await t.page.locator('#inline_edit_form tr.group').count();
if (groups < 2) t.problems.push(`${groups} group headers`);
if (await t.page.locator('#inline_edit_form tr.group span.expander svg').count() !== groups) t.problems.push('expander without SVG icon');
const totals = await t.page.locator('#inline_edit_form tr.inline_group_totals').count();
if (totals !== groups) t.problems.push(`${totals} group totals for ${groups} groups`);
const bugTotal = await t.page.locator('#inline_edit_form tr.inline_group_totals td[id$="_total_estimated_hours"]').first().innerText();
await t.shot('grouped', `Grouped by tracker: ${groups} groups with the expander icon and estimated time per group (first: ${bugTotal})`);

await t.page.locator('#inline_edit_form tr.group span.expander').first().click();
t.check('fold one group');
const issueRows = await t.page.locator('#inline_edit_form tbody tr.issue').count();
const hidden = issueRows - await t.page.locator('#inline_edit_form tbody tr.issue:visible').count();
if (hidden < 1) t.problems.push('folding the first group hid nothing');
await t.shot('one-folded', 'The first group folded: its issues and its totals row are hidden, the icon points right');

await t.page.locator('#inline_edit_form tr.group').first().hover();
await t.page.locator('#inline_edit_form tr.group a.toggle-all').first().click();
t.check('expand all');
await t.page.locator('#inline_edit_form tr.group').first().hover();
await t.page.locator('#inline_edit_form tr.group a.toggle-all').first().click();
t.check('collapse all');
if (await t.page.locator('#inline_edit_form tbody tr.issue:visible').count()) t.problems.push('collapse all left issues visible');
await t.shot('collapsed', '"Collapse all" folds every group without a JavaScript error');
await t.page.locator('#inline_edit_form tr.group').first().hover();
await t.page.locator('#inline_edit_form tr.group a.toggle-all').first().click();
t.check('expand all again');
if (await t.page.locator('#inline_edit_form tbody tr.issue:visible').count() !== issueRows) t.problems.push('expand all left issues hidden');
await t.shot('expanded', '"Expand all" shows every group again');

await t.done();
