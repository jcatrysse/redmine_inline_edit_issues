// The form's own JavaScript (assets/javascripts/inline_edit_issues.js): an edited field turns
// red, hovering shows the original value, estimated time totals follow the inputs, Reset puts
// everything back, Cancel returns to the list without saving.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('client-side');

await t.login('manager');
await t.go(`/projects/${P}/issues?set_filter=1&status_id=o&sort=id`);
const ids = await t.page.$$eval('table.issues tr.issue', rows => Object.fromEntries(rows.map(r => [r.querySelector('td.subject').innerText.trim(), r.id.replace('issue-', '')])));
const a = ids['E2E unassigned issue'], b = ids['E2E related issue'];
const back = `/projects/${P}/issues`;
await t.go(`/projects/${P}/inline_issues/edit_multiple?ids[]=${a}&ids[]=${b}&set_filter=1&c[]=subject&c[]=estimated_hours&back_url=${encodeURIComponent(back)}`);

const subject = t.page.locator(`input[name="issues[${a}][subject]"]`);
const hours = t.page.locator(`input[name="issues[${a}][estimated_hours]"]`);
const total = t.page.locator('td#total-estimated_hours');
const totalBefore = await total.innerText();
const hoursBefore = await hours.inputValue();

await subject.click();
await subject.fill('E2E unassigned issue, edited');
await subject.press('Tab');
await subject.hover();
await t.page.waitForSelector('#field_original', { state: 'visible', timeout: 5000 }).catch(() => t.problems.push('original value tooltip not shown'));
const color = await subject.evaluate(e => getComputedStyle(e).color);
if (color !== 'rgb(255, 0, 0)') t.problems.push(`edited subject is ${color}, not red`);
const original = await t.page.locator('#field_original_value').innerText();
if (original !== 'E2E unassigned issue') t.problems.push(`tooltip shows "${original}"`);
await t.shot('edited-hover', 'An edited field is red; hovering it shows the original value', { full: false });

await hours.click();
await hours.fill('10');
await hours.press('Tab');
const expected = (parseFloat(totalBefore) - parseFloat(hoursBefore || '0') + 10).toFixed(2);
if ((await total.innerText()) !== expected) t.problems.push(`total is ${await total.innerText()}, expected ${expected}`);
await t.shot('total', `Estimated time changed to 10: the total follows (${totalBefore} -> ${expected}) before saving`, { full: false });

await t.page.click('#inline_edit_reset');
await t.page.waitForTimeout(300);
if ((await subject.inputValue()) !== 'E2E unassigned issue') t.problems.push('reset did not restore the subject');
if ((await total.innerText()) !== totalBefore) t.problems.push(`reset: total ${await total.innerText()}, expected ${totalBefore}`);
if ((await subject.evaluate(e => getComputedStyle(e).color)) === 'rgb(255, 0, 0)') t.problems.push('reset: subject still red');
await t.shot('reset', 'Reset restores every value and the total');

await subject.fill('Not saved');
await t.page.locator('#inline_edit_form a', { hasText: /^Cancel$/ }).click();
await t.settle();
t.check('cancel');
if (new URL(t.page.url()).pathname !== back) t.problems.push(`cancel went to ${t.page.url()}`);
if (await t.page.locator('table.issues td.subject', { hasText: 'Not saved' }).count()) t.problems.push('cancel saved the change');
await t.shot('cancel', 'Cancel goes back to the issue list and saves nothing');

await t.done();
