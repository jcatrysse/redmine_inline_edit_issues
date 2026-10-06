// The "original value" tooltip of the form: it shows the value as text, never as HTML (a
// subject with markup used to run when another user hovered it), and an empty original value
// as the translated "none" (it was a hard-coded "--BLANK--").
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const SUBJECT = 'E2E <img src=x onerror="window.__xss=1"> markup';
const t = await e2e('tooltip');
const auth = 'Basic ' + Buffer.from(`manager:${process.env.RMP_USER_PASSWORD || 'Redmine7Test!'}`).toString('base64');

await t.login('manager');
// the issue with markup in its subject, created once through the REST API
let r = await t.page.request.get(`${t.BASE}/projects/${P}/issues.json?status_id=*&limit=100`, { headers: { Authorization: auth } });
let issue = (await r.json()).issues.find(i => i.subject === SUBJECT);
if (!issue) {
  r = await t.page.request.post(`${t.BASE}/projects/${P}/issues.json`, { headers: { Authorization: auth }, data: { issue: { subject: SUBJECT } } });
  if (r.status() !== 201) throw new Error(`create issue: HTTP ${r.status()}`);
  issue = (await r.json()).issue;
}

await t.go(`/projects/${P}/inline_issues/edit_multiple?ids[]=${issue.id}&set_filter=1&c[]=subject&c[]=estimated_hours`);
const subject = t.page.locator(`input[name="issues[${issue.id}][subject]"]`);
await subject.hover();
await t.page.waitForSelector('#field_original', { state: 'visible', timeout: 5000 }).catch(() => t.problems.push('tooltip not shown'));
await t.page.waitForTimeout(500);
if (await t.page.evaluate(() => window.__xss)) t.problems.push('the markup of the subject ran in the tooltip');
if (await t.page.locator('#field_original img').count()) t.problems.push('the tooltip contains an <img> element');
const shown = await t.page.locator('#field_original_value').innerText();
if (shown !== SUBJECT) t.problems.push(`tooltip shows "${shown}"`);
await t.shot('markup-as-text', 'A subject with HTML markup is shown as text in the tooltip; nothing runs', { full: false });

const hours = t.page.locator(`input[name="issues[${issue.id}][estimated_hours]"]`);
await hours.hover();
await t.page.waitForTimeout(300);
const blank = await t.page.locator('#field_original_value').innerText();
if (blank !== 'none') t.problems.push(`empty original value shows "${blank}", expected "none"`);
await t.shot('empty-value', 'An empty original value shows the translated "none"', { full: false });

await t.done();
