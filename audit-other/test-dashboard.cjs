// Offline calls to real dashboard functions; no page bootstrap, fetch or macros.
const fs = require('node:fs');
const path = require('node:path');
const vm = require('node:vm');
const assert = require('node:assert/strict');
const source = fs.readFileSync(process.env.CAU_DASHBOARD_SOURCE || path.join(__dirname, '../Proyecto_HD/dashboard_incidencias.html'), 'utf8');
function load(name, context) {
  const start = source.indexOf('function ' + name + '(');
  assert.ok(start >= 0, 'function exists');
  const oneLine = source.slice(start).split('\n')[0];
  let body;
  if (oneLine.endsWith('}')) body = oneLine;
  else {
    const end = source.indexOf('\n}', start);
    body = source.slice(start, end + 2);
  }
  vm.runInContext(body, context);
}
const elements = {};
const context = vm.createContext({
  allData: [], COL: {desc:'desc', id:'id',fecha:'fecha',prov:'prov',clase:'clase'},
  window: {},
  document: {getElementById(id) { return elements[id] ||= {style:{},innerHTML:''}; }},
  setTimeout() { throw new Error('unexpected timer'); }
});
const which = process.argv[2] || 'repeated';
if (which === 'repeated') {
  load('getVal', context); load('computeRepeated', context);
  context.allData = [1,2,3].map(n => ({id:'OFFLINE-'+n,desc:'fallo de impresora',fecha:'01/01/2026',prov:'fixture'}));
  const result = vm.runInContext('computeRepeated()', context);
  assert.equal(result.length, 1, 'repeated descriptions visible');
  assert.equal(result[0].c, 3, 'all duplicates counted');
} else if (which === 'csv') {
  load('parseLine', context); load('parseCSV', context);
  context.csv = 'id,desc,clase\r\nOFFLINE,"texto, con coma y ""cita""",tipo\r\nOFFLINE2,"linea1\nlinea2",tipo';
  const rows = vm.runInContext('parseCSV(csv)', context);
  assert.equal(rows[0].desc, 'texto, con coma y "cita"', 'quoted commas and escaped quotes');
  assert.equal(rows[0].clase, 'tipo', 'columns not shifted');
  assert.equal(rows[1].desc, 'linea1\nlinea2', 'embedded newline');
} else if (which === 'html-debug') {
  load('escHtml', context); load('showDebugInfo', context);
  context.window._cols = Object.fromEntries(['id','desc','fecha','clase','cargo','prov','diario','usuario','correo','telefono','tipo','categoria'].map(k=>[k,'<img src=x onerror=fixture()>']));
  vm.runInContext('showDebugInfo()', context);
  assert.ok(!elements.colDebug.innerHTML.includes('<img'), 'CSV header must not create HTML element');
} else if (which === 'html-stats') {
  load('escHtml', context); load('renderStats', context);
  context.COL.clase = '<img src=x onerror=fixture()>';
  context.stats = {total:1,urgentes:0,afecta:0,nopuedo:0,nadriano:1,catSinClasificar:0,tipoCount:{}};
  vm.runInContext('renderStats(stats)', context);
  assert.ok(!elements.statsRow.innerHTML.includes('<img'), 'CSV class header must not create HTML element');
} else throw new Error('Unknown case');
console.log('PASS: ' + which);
