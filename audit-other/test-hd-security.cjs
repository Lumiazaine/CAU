const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const source=fs.readFileSync(require('node:path').join(__dirname,'../Proyecto_HD/dashboard_incidencias.html'),'utf8');
function load(name,c){const start=source.indexOf('function '+name+'(');assert.ok(start>=0,'missing '+name);vm.runInContext(source.slice(start,source.indexOf('\n}',start)+2),c)}
const requests=[],nodes={};
const c=vm.createContext({location:{protocol:'http:',hostname:'localhost',origin:'http://localhost:8080'},_hdToken:'OFFLINE-token',fetch:(url,opts)=>{requests.push({url,opts});return Promise.resolve({ok:true,status:200,json:()=>Promise.resolve({ok:true,count:0,data:[]})})},document:{getElementById:id=>nodes[id]??={value:'OFFLINE-token',style:{},classList:{add(){},remove(){}},textContent:'',innerHTML:''}},setHdStatus(){},renderHelpdesk(){},formatDate(){},_hdCache:null,HD_API:'/api/helpdesk'});
(async()=>{
 load('fetchHelpdesk',c);vm.runInContext('fetchHelpdesk()',c);await new Promise(r=>setImmediate(r));
 assert.equal(requests[0]?.url,'/api/helpdesk','API same origin');
 assert.equal(requests[0]?.opts?.headers?.Authorization,'Bearer OFFLINE-token','bearer required');
 assert.equal(requests[0]?.opts?.cache,'no-store');
 assert.ok(!requests[0]?.url.includes('OFFLINE-token'));
 requests.length=0;c.location.protocol='file:';vm.runInContext('fetchHelpdesk()',c);await new Promise(r=>setImmediate(r));assert.equal(requests.length,0,'file origin disabled');
 c.location.protocol='http:';c._hdToken='';vm.runInContext('fetchHelpdesk()',c);await new Promise(r=>setImmediate(r));assert.equal(requests.length,0,'empty token prevents requests');
 assert.ok(!/localStorage[^\n]*(?:[Tt]oken|[Pp]assword)/.test(source),'no secret persistence');
 assert.ok(!source.includes('https://cdn.jsdelivr.net'),'no third-party executable script with bearer in memory');
 console.log('PASS: HelpDesk same-origin bearer, memory-only, file/anonymous disabled, no CDN script');
})().catch(e=>{console.error(e.message);process.exitCode=1});
