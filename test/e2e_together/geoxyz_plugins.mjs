// The GEOxyz integrations of the inline edit form, on a Redmine that also runs
// redmine_itil_priority and redmine_depending_custom_fields (not part of ./.codex/e2e.sh,
// which runs test/e2e only; see "Together" in docs/REDMINE7-MIGRATION.md):
// ITIL impact and urgency as selects whose change recalculates the priority (a0865eb),
// depending lists filtered by their parent (b365a80), the extended user field (72342eb),
// the custom_field_sql formats sql (list from a query) and sql_search (autocomplete, 46d01a2),
// all saved through safe_attributes.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('together');
const auth = 'Basic ' + Buffer.from(`admin:${process.env.RMP_ADMIN_PASSWORD || 'Redmine7Test!'}`).toString('base64');
async function api(path) {
  const r = await t.page.request.get(`${t.BASE}${path}`, { headers: { Authorization: auth } });
  if (r.status() !== 200) throw new Error(`API ${path}: HTTP ${r.status()}`);
  return r.json();
}

await t.login('manager');
await t.go(`/projects/${P}/issues?set_filter=1&c[]=subject`);
const cf = await t.page.$$eval('#available_c option, #selected_c option', os => Object.fromEntries(os.map(o => [o.textContent.trim(), o.value])));
const country = cf['E2E country'], city = cf['E2E city'], xuser = cf['E2E extended user'];
const sql = cf['E2E sql'], sqlSearch = cf['E2E sql search'];
for (const [n, v] of Object.entries({ impact: cf['Impact'], urgency: cf['Urgency'], country, city, xuser, sql, sqlSearch })) if (!v) t.problems.push(`column ${n} not available: ${Object.keys(cf).join(', ')}`);
await t.go(`/projects/${P}/issues?set_filter=1&status_id=o&sort=id`);
const ids = await t.page.$$eval('table.issues tr.issue', rows => Object.fromEntries(rows.map(r => [r.querySelector('td.subject').innerText.trim(), r.id.replace('issue-', '')])));
const id = ids['E2E unassigned issue'];
const cid = n => n.replace('cf_', '');

await t.go(`/projects/${P}/inline_issues/edit_multiple?ids[]=${id}&ids[]=${ids['E2E related issue']}&set_filter=1&c[]=subject&c[]=priority&c[]=${cf['Impact']}&c[]=${cf['Urgency']}&c[]=${country}&c[]=${city}&c[]=${xuser}&c[]=${sql}&c[]=${sqlSearch}&back_url=${encodeURIComponent(`/projects/${P}/issues`)}`);
const impact = t.page.locator(`select[name="issues[${id}][impact_id]"]`);
const urgency = t.page.locator(`select[name="issues[${id}][urgency_id]"]`);
if (!(await impact.count()) || !(await urgency.count())) t.problems.push('impact/urgency are not selects');
await t.shot('form', 'ITIL impact and urgency, the depending lists and the extended user field as inputs on the inline form');

const before = (await api(`/issues/${id}.json`)).issue;
// re-runnable: toggle between the corners of the matrix, so the priority must change
const level = String(before.impact_id) === '1' ? '3' : '1';
await impact.selectOption(level);
await urgency.selectOption(level);
await t.page.selectOption(`select[name="issues[${id}][custom_field_values][${cid(country)}]"]`, 'BE');
const citySelect = t.page.locator(`select[name="issues[${id}][custom_field_values][${cid(city)}]"]`);
const cityOptions = await citySelect.locator('option').evaluateAll(os => os.filter(o => !o.hidden && o.style.display !== 'none' && !o.disabled).map(o => o.value).filter(Boolean));
if (cityOptions.includes('Amsterdam') || !cityOptions.includes('Gent')) t.problems.push(`city options for BE: ${cityOptions}`);
await citySelect.selectOption('Gent');
const xuserSelect = t.page.locator(`select[name="issues[${id}][custom_field_values][${cid(xuser)}]"]`);
const xuserOptions = await xuserSelect.locator('option').evaluateAll(os => os.filter(o => !o.disabled).map(o => [o.value, o.textContent.trim()]).filter(([v]) => v));
if (!xuserOptions.length) t.problems.push('extended user field has no options');
else await xuserSelect.selectOption(xuserOptions[0][0]);
await t.page.selectOption(`select[name="issues[${id}][custom_field_values][${cid(sql)}]"]`, { label: 'Support' });
const search = t.page.locator(`input[name="issues[${id}][custom_field_values][${cid(sqlSearch)}]"]`);
await search.fill('');
await search.click();
await search.pressSequentially('relat', { delay: 80 });
const suggestion = t.page.locator('ul.ui-autocomplete li', { hasText: 'E2E related issue' }).first();
await suggestion.waitFor({ timeout: 10000 }).catch(() => t.problems.push('sql_search: no suggestion'));
await t.shot('sql-search', 'sql_search: typing "relat" in the inline field asks custom_field_sql and offers "E2E related issue"', { full: false });
await suggestion.click().catch(() => {});
if ((await search.inputValue()) !== 'E2E related issue') t.problems.push(`sql_search value: ${await search.inputValue()}`);
await t.shot('changed', `Impact ${level}, urgency ${level}, country BE (cities limited to ${cityOptions.join('/')}), city Gent, extended user ${xuserOptions[0] && xuserOptions[0][1]}`);
await t.page.click('#inline_edit_form input[type=submit]');
await t.settle();
t.check('save');
if (!(await t.page.locator('#flash_notice').count())) t.problems.push(`no success notice: ${await t.page.locator('#flash_error').innerText().catch(() => '')}`);

const after = (await api(`/issues/${id}.json`)).issue;
// the priority column was on the form but unchanged: impact x urgency decide, the link stays
if (after.priority.id === before.priority.id) t.problems.push(`priority not recalculated from impact x urgency: still ${after.priority.name}`);
if (after.itil_priority_linked === false) t.problems.push('the priority was unlinked from impact and urgency');
const cfv = name => (after.custom_fields.find(c => c.name === name) || {}).value;
if (String(after.impact_id) !== level || String(after.urgency_id) !== level) t.problems.push(`impact/urgency not saved: ${after.impact_id}/${after.urgency_id}`);
if (cfv('E2E country') !== 'BE' || cfv('E2E city') !== 'Gent') t.problems.push(`depending lists not saved: ${cfv('E2E country')}/${cfv('E2E city')}`);
if (!cfv('E2E extended user')) t.problems.push('extended user not saved');
if (cfv('E2E sql') !== String((await api('/trackers.json')).trackers.find(tr => tr.name === 'Support').id)) t.problems.push(`sql field not saved: ${cfv('E2E sql')}`);
if (cfv('E2E sql search') !== 'E2E related issue') t.problems.push(`sql_search field not saved: ${cfv('E2E sql search')}`);
await t.go(`/issues/${id}`);
await t.shot('saved', `Saved: priority ${before.priority.name} -> ${after.priority.name} from impact x urgency; depending lists, extended user, sql and sql_search in the history`);

await t.done();
