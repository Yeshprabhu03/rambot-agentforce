// Convert exported CSVs into sf data import tree files (plan + per-object JSON).
const fs = require('fs'), path = require('path');
const dir = process.argv[2], out = path.join(dir, 'tree');
function parse(text) {
  const rows = []; let row = [], f = '', q = false;
  for (let i = 0; i < text.length; i++) {
    const c = text[i];
    if (q) { if (c === '"') { if (text[i+1] === '"') { f += '"'; i++; } else q = false; } else f += c; }
    else if (c === '"') q = true;
    else if (c === ',') { row.push(f); f = ''; }
    else if (c === '\n') { row.push(f); rows.push(row); row = []; f = ''; }
    else if (c !== '\r') f += c;
  }
  if (f || row.length) { row.push(f); rows.push(row); }
  const [h, ...data] = rows; return data.filter(r => r.length > 1).map(r => Object.fromEntries(h.map((k, i) => [k, r[i]])));
}
const num = /(__c)$/;
function clean(rec, drop) {
  const o = {};
  for (const [k, v] of Object.entries(rec)) {
    if (k === 'Id' || drop.includes(k) || k.includes('.') || v === '' || v === undefined) continue;
    o[k] = v === 'true' ? true : v === 'false' ? false : (/^-?\d+(\.\d+)?$/.test(v) && !/Name|Code|Year|URL|Email|Term/i.test(k) ? Number(v) : v);
  }
  return o;
}
const plan = [];
function emit(obj, recs, refFn) {
  const records = recs.map((r, i) => ({ attributes: { type: obj, referenceId: obj + 'Ref' + i }, ...refFn(r, i) }));
  fs.writeFileSync(path.join(out, obj + '.json'), JSON.stringify({ records }, null, 1));
  plan.push({ sobject: obj, saveRefs: obj === 'Application__c', resolveRefs: obj === 'Advising_Appointment__c', files: [obj + '.json'] });
}
const load = o => parse(fs.readFileSync(path.join(dir, o + '.csv'), 'utf8'));
emit('Program__c', load('Program__c'), r => clean(r, []));
emit('Faculty__c', load('Faculty__c'), r => clean(r, []));
emit('Campaign', load('Campaign'), r => clean(r, []));
const apps = load('Application__c').sort((a, b) => a.Name.localeCompare(b.Name));
const idx = Object.fromEntries(apps.map((a, i) => [a.Name, i]));
emit('Application__c', apps, r => clean(r, ['Name']));
emit('Advising_Appointment__c', load('Advising_Appointment__c'), r => ({ ...clean(r, ['Name']), Application__c: '@Application__cRef' + idx[r['Application__r.Name']] }));
fs.writeFileSync(path.join(out, 'plan.json'), JSON.stringify(plan, null, 1));
console.log(plan.map(p => p.sobject).join(', '), '| apps:', apps.map(a => a.Name).join(' '));
