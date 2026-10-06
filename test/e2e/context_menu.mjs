// "Edit Inline" in the issue list's context menu: shown with the plugin's permission
// (SVG icon, link to the inline edit form with the list's columns and sort), disabled
// without it, absent on a single issue.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('context-menu');
const LIST = `/projects/${P}/issues?set_filter=1&c[]=tracker&c[]=subject&c[]=estimated_hours&sort=subject`;

async function openMenu(rows) {
  await t.go(LIST);
  for (let i = 0; i < rows; i++) await t.page.check(`table.issues tr.issue td.checkbox input >> nth=${i}`);
  await t.page.click('table.issues tr.issue td.subject >> nth=0', { button: 'right' });
  await t.page.waitForSelector('#context-menu ul', { timeout: 10000 }).catch(() => t.problems.push('context menu did not open'));
  t.check('context menu');
  return t.page.locator('#context-menu a', { hasText: 'Edit Inline' });
}

await t.login('manager');
let link = await openMenu(2);
const href = await link.getAttribute('href');
if (!/\/projects\/e2e-project\/inline_issues\/edit_multiple\?/.test(href || '')) t.problems.push(`manager: link is ${href}`);
for (const part of ['c%5B%5D=subject', 'c%5B%5D=estimated_hours', 'sort=subject']) {
  if (!(href || '').includes(part)) t.problems.push(`manager: link misses ${part}`);
}
if (await link.locator('svg').count() !== 1) t.problems.push('manager: no SVG icon on the item');
if (await link.evaluate(a => a.classList.contains('disabled'))) t.problems.push('manager: item disabled');
await t.shot('manager', 'Two issues selected: "Edit Inline" with the edit icon, enabled for a member with the permission', { full: false });
await link.click();
await t.page.waitForURL(/inline_issues\/edit_multiple/);
await t.settle();
t.check('follow the item');
if (await t.page.locator('#inline_edit_form tbody tr.issue').count() !== 2) t.problems.push('form does not show the 2 selected issues');
const head = await t.page.locator('#inline_edit_form thead').innerText();
if (!/Subject/.test(head) || !/Estimated time/.test(head)) t.problems.push(`form columns are not the list's: ${head}`);
await t.shot('opens-form', 'The item opens the inline edit form on the selected issues with the columns of the list');

await openMenu(1);
if (await t.page.locator('#context-menu a', { hasText: 'Edit Inline' }).count()) t.problems.push('single issue: item shown');
await t.shot('single-issue', 'On one issue the item is not offered (core edit is there)', { full: false });

await t.login('developer');
link = await openMenu(2);
if (!(await link.evaluate(a => a.classList.contains('disabled')))) t.problems.push('developer: item not disabled');
if ((await link.getAttribute('href')) !== '#') t.problems.push('developer: disabled item still links somewhere');
await t.shot('developer-disabled', 'A member who may edit issues but lacks "Edit inline" sees the item disabled', { full: false });

await t.login('reporter');
link = await openMenu(2);
if (!(await link.evaluate(a => a.classList.contains('disabled')))) t.problems.push('reporter: item not disabled');
await t.shot('reporter-disabled', 'A member without edit rights sees the item disabled', { full: false });

await t.done();
