const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm');
const root=path.resolve(__dirname,'..');
const results=[];
for(const file of ['Proyecto_HD/dashboard_incidencias.html','@web/@DRIANO.html']) {
 const html=fs.readFileSync(path.join(root,file),'utf8');
 const matches=[...html.matchAll(/<script\b([^>]*)>([\s\S]*?)<\/script\s*>/gi)];
 const record={file,inline:0,external:0,errors:[]};
 for(const [i,m] of matches.entries()) {
  if(/\bsrc\s*=/i.test(m[1])) {record.external++;continue;}
  if(/\btype\s*=\s*["'](?:application\/ld\+json|application\/json)/i.test(m[1]))continue;
  record.inline++;
  try {new vm.Script(m[2],{filename:file});} catch(e) {record.errors.push({script:i,type:e.name});}
 }
 results.push(record);
}
for(const file of fs.readdirSync(path.join(root,'Proyecto_HD')).filter(f=>f.endsWith('.js'))) {
 const record={file:'Proyecto_HD/'+file,errors:[]};
 try {new vm.Script(fs.readFileSync(path.join(root,record.file),'utf8'));}catch(e){record.errors.push({type:e.name});}
 results.push(record);
}
console.log(JSON.stringify(results,null,2));
if(results.some(r=>r.errors.length))process.exitCode=1;
