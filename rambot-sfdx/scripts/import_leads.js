// Build a tree import (Leads + CampaignMembers) from the old org's exported demo leads.
const fs=require('fs');
function parse(t){const rows=[];let row=[],f='',q=false;for(let i=0;i<t.length;i++){const c=t[i];if(q){if(c==='"'){if(t[i+1]==='"'){f+='"';i++}else q=false}else f+=c}else if(c==='"')q=true;else if(c===','){row.push(f);f=''}else if(c==='\n'){row.push(f);rows.push(row);row=[];f=''}else if(c!=='\r')f+=c}if(f||row.length){row.push(f);rows.push(row)}const[h,...d]=rows;return d.filter(r=>r.length>1).map(r=>Object.fromEntries(h.map((k,i)=>[k,r[i]])))}
const skip=['test.student@example.com','testcase4@example.com'];
const leads=parse(fs.readFileSync('data/Lead.csv','utf8')).filter(l=>!skip.includes(l.Email));
const camps=JSON.parse(fs.readFileSync('/tmp/camps.json','utf8')).result.records;
const campId=n=>{const c=camps.filter(c=>c.Name===n);const pick=c.find(c=>String(c.Event_Time__c).startsWith('2026-11-10'))||c[0];return pick&&pick.Id};
const cms=parse(fs.readFileSync('data/CampaignMember.csv','utf8'));
const recs=leads.map((l,i)=>{const r={attributes:{type:'Lead',referenceId:'L'+i}};for(const k of['FirstName','LastName','Email','Company','LeadSource','Status','Program_Interest__c','Intended_Term__c','Description'])if(l[k])r[k]=l[k];r.Is_International__c=l.Is_International__c==='true';
 const mine=cms.filter(c=>c['Lead.Email']===l.Email).map((c,j)=>({attributes:{type:'CampaignMember',referenceId:'CM'+i+'_'+j},CampaignId:campId(c['Campaign.Name']),Status:c.Status}));
 if(mine.length)r.CampaignMembers={records:mine};return r});
fs.writeFileSync('data/tree/Lead_with_CM.json',JSON.stringify({records:recs},null,1));
console.log(recs.map(r=>r.FirstName+' '+r.LastName+(r.CampaignMembers?' +'+r.CampaignMembers.records.length+' event':'')).join(', '));
