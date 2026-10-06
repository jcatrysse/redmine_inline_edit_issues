// Saving the inline edit form (/inline_issues/update_multiple): a change is saved, noticed and
// recorded in the issue's history; a validation error is reported and saves nothing; forged
// requests (an issue of a private project, a user without the permission, a field that is
// not editable) are refused or ignored. The forged requests are real form posts with the
// user's own CSRF token, so the screenshots show what the browser got.
import { e2e } from '../../.codex/e2e/lib.mjs';

const P = 'e2e-project';
const t = await e2e('save');

async function issueIds(project) {
  await t.go(`/projects/${project}/issues?set_filter=1&status_id=*&sort=id&per_page=100`);
  return t.page.$$eval('table.issues tr.issue', rows => Object.fromEntries(rows.map(r => [r.querySelector('td.subject').innerText.trim(), r.id.replace('issue-', '')])));
}
async function apiIssue(id) {
  // REST API as manager (basic auth), who sees both projects
  const auth = 'Basic ' + Buffer.from(`manager:${process.env.RMP_USER_PASSWORD || 'Redmine7Test!'}`).toString('base64');
  const r = await t.page.request.get(`${t.BASE}/issues/${id}.json`, { headers: { Authorization: auth } });
  if (r.status() !== 200) throw new Error(`API /issues/${id}.json: HTTP ${r.status()}`);
  return (await r.json()).issue;
}
// Posts a hand-made update form from the current page, as the logged in user
async function forge(fields, projectId = P) {
  const [resp] = await Promise.all([
    t.page.waitForNavigation(),
    t.page.evaluate(({ fields, projectId }) => {
      const f = document.createElement('form');
      f.method = 'post';
      f.action = `/inline_issues/update_multiple?project_id=${projectId}&back_url=${encodeURIComponent('/projects/' + projectId + '/issues')}`;
      const add = (n, v) => { const i = document.createElement('input'); i.type = 'hidden'; i.name = n; i.value = v; f.appendChild(i); };
      add('_method', 'put');
      add('authenticity_token', document.querySelector('meta[name=csrf-token]').content);
      for (const [n, v] of Object.entries(fields)) add(n, v);
      document.body.appendChild(f);
      f.submit();
    }, { fields, projectId }),
  ]);
  await t.settle();
  return resp ? resp.status() : 0;
}

await t.login('manager');
const ids = await issueIds(P);
const priv = (await issueIds('e2e-private'))['E2E private issue'];
const related = ids['E2E related issue'];
const unassigned = ids['E2E unassigned issue'];
const listCf = await t.page.$$eval('#available_c option, #selected_c option', os => (os.find(o => o.textContent.trim() === 'E2E list') || {}).value);
const listId = listCf.replace('cf_', '');

// 1. a change is saved
const form = `/projects/${P}/inline_issues/edit_multiple?ids[]=${related}&ids[]=${unassigned}&set_filter=1&c[]=subject&c[]=status&c[]=${listCf}&back_url=${encodeURIComponent(`/projects/${P}/issues`)}`;
await t.go(form);
const select = t.page.locator(`select[name="issues[${related}][custom_field_values][${listId}]"]`);
const before = await select.inputValue();
const after = before === 'Beta' ? 'Gamma' : 'Beta';
await select.selectOption(after);
await t.shot('changed', `Manager changed "E2E list" of #${related} to ${after}: the changed field turns red`);
await t.page.click('#inline_edit_form input[type=submit]');
await t.settle();
t.check('save');
if (!new URL(t.page.url()).pathname.endsWith(`/projects/${P}/issues`)) t.problems.push(`after save: on ${t.page.url()}`);
if (!(await t.page.locator('#flash_notice', { hasText: 'Successful update.' }).count())) t.problems.push('no success notice');
await t.shot('saved', 'Back on the issue list with "Successful update."');
await t.go(`/issues/${related}`);
const journal = t.page.locator('#history .journal', { hasText: `E2E list changed from` }).last();
if (!(await journal.count()) || !(await journal.innerText()).includes(after)) t.problems.push('the change is not in the history');
await t.shot('history', 'The inline change is recorded in the issue history, by the manager');

// 2. a validation error saves nothing and is reported
await t.go(form);
await t.page.fill(`input[name="issues[${unassigned}][subject]"]`, '');
await t.page.click('#inline_edit_form input[type=submit]');
await t.settle();
t.check('save blank subject');
const err = await t.page.locator('#flash_error').innerText().catch(() => '');
if (!err.includes(`Issue ${unassigned}: Subject cannot be blank`)) t.problems.push(`validation error not shown: "${err}"`);
if ((await apiIssue(unassigned)).subject !== 'E2E unassigned issue') t.problems.push('blank subject was saved');
await t.shot('validation-error', 'A blank subject is refused with the issue number; nothing is saved');

// 3. fields the user may not set are ignored: author (no editauthor plugin here), closed_on
const authorBefore = (await apiIssue(related)).author.id;
await t.go(`/projects/${P}/issues`);
let status = await forge({ [`issues[${related}][author_id]`]: '1', [`issues[${related}][closed_on]`]: '2001-01-01 00:00:00', [`issues[${related}][subject]`]: 'E2E related issue' });
if (status !== 200) t.problems.push(`forged author_id: HTTP ${status}`);
const rel = await apiIssue(related);
if (rel.author.id !== authorBefore || rel.closed_on) t.problems.push(`author_id/closed_on were changed: ${rel.author.id} ${rel.closed_on}`);
await t.shot('unsafe-ignored', 'A forged author_id and closed_on are ignored: only safe attributes are written');

// 4. refusals
await t.login('outsider');
await t.go('/projects');
status = await forge({ [`issues[${priv}][subject]`]: 'Hacked by outsider' });
if (status !== 403) t.problems.push(`outsider on a private issue: HTTP ${status}, expected 403`);
await t.shot('outsider-private-refused', 'A non-member posting a change to an issue of the private project is refused (403)');

await t.login('reporter');
await t.go(`/projects/${P}/issues`);
status = await forge({ [`issues[${related}][subject]`]: 'Hacked by reporter' });
if (status !== 403) t.problems.push(`reporter: HTTP ${status}, expected 403`);
await t.shot('reporter-refused', 'A member without the permission is refused (403)');

await t.login('developer');
await t.go(`/projects/${P}/issues`);
status = await forge({ [`issues[${related}][subject]`]: 'Hacked by developer' });
if (status !== 403) t.problems.push(`developer: HTTP ${status}, expected 403`);
await t.shot('developer-refused', 'A member who may edit issues but lacks "Edit inline" is refused (403)');
status = await forge({ [`issues[${priv}][subject]`]: 'Hacked' }, P);
if (status !== 403) t.problems.push(`developer with project_id of a project where he is a member, issue of the private project: HTTP ${status}`);

await t.login('manager');
await t.go(`/projects/${P}/issues`);
status = await forge({ [`issues[999999][subject]`]: 'Nothing' });
if (status !== 404) t.problems.push(`unknown issue: HTTP ${status}, expected 404`);
await t.shot('unknown-issue', 'An unknown issue id answers 404 and saves nothing');
for (const [id, subject] of [[priv, 'E2E private issue'], [related, 'E2E related issue']]) {
  if ((await apiIssue(id)).subject !== subject) t.problems.push(`issue ${id} was changed by a refused request`);
}

await t.done();
