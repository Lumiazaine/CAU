// predictor_data.js - generated 2026-06-23 12:24
'use strict';
const TIPO_PRIOR={'Motor Tramitaci�n':{'6.3':0.169,'6.2':0.153,'9':0.088,'18':0.071,'6.4':0.057,'6.1':0.055,'17':0.037,'21':0.035,'2.1':0.028,'10':0.028,'24':0.023,'25':0.023,'1':0.02,'33':0.019,'76':0.017,'14':0.014,'2':0.012,'46':0.012,'40':0.011,'1.1':0.011,'44':0.011,'15':0.01,'85':0.01,'22':0.01,'41':0.008,'36':0.008,'32':0.007,'3':0.007,'59':0.007,'78':0.006,'42':0.006,'20':0.006,'34':0.005,'26':0.004,'4':0.003,'11':0.003,'45':0.002,'75':0.002,'6':0.001,'68':0.001,'39':0.001,'47':0.001},'Escritorio Judicial':{'43':0.388,'27':0.115,'7':0.111,'31':0.104,'38':0.093,'29':0.093,'23':0.07,'63':0.027},'Gesti�n y Administraci�n':{'51':0.302,'70':0.229,'58':0.229,'67':0.083,'62':0.083,'69':0.073},'Editor documentos':{'35':0.383,'57':0.204,'37':0.179,'49':0.173,'77':0.049,'56':0.006,'86':0.006},'Registro y Reparto':{'84':0.509,'83':0.491},'Integraci�n Lexnet':{'74':0.605,'19':0.316,'73':0.079},'Gesti�n EJE':{'16':0.887,'66':0.113},'Agenda Programada':{'30':0.973,'54':0.027},'Normas de Reparto':{'8':1},'Ejecutorias':{'60':0.875,'61':0.125},'Procedimientos ETL Migraci�n':{'82':1},'Portafirmas':{'81':1},'Agenda Calendario':{'53':1},'SCNE':{'12':0.6,'28':0.4}};
const CASO_TIPO={'1.1':{'Motor Tramitaci�n':1},'1':{'Motor Tramitaci�n':1},'2':{'Motor Tramitaci�n':1},'2.1':{'Motor Tramitaci�n':1},'3':{'Motor Tramitaci�n':1},'4':{'Motor Tramitaci�n':1},'6.2':{'Motor Tramitaci�n':1},'6.3':{'Motor Tramitaci�n':1},'6.4':{'Motor Tramitaci�n':1},'6.1':{'Motor Tramitaci�n':1},'7':{'Escritorio Judicial':1},'8':{'Normas de Reparto':1},'9':{'Motor Tramitaci�n':1},'10':{'Motor Tramitaci�n':1},'11':{'Motor Tramitaci�n':1},'12':{'SCNE':1},'14':{'Motor Tramitaci�n':1},'15':{'Motor Tramitaci�n':1},'16':{'Gesti�n EJE':1},'17':{'Motor Tramitaci�n':1},'18':{'Motor Tramitaci�n':1},'19':{'Integraci�n Lexnet':1},'20':{'Motor Tramitaci�n':1},'21':{'Motor Tramitaci�n':1},'22':{'Motor Tramitaci�n':1},'23':{'Escritorio Judicial':1},'24':{'Motor Tramitaci�n':1},'25':{'Motor Tramitaci�n':1},'26':{'Motor Tramitaci�n':1},'27':{'Escritorio Judicial':1},'29':{'Escritorio Judicial':1},'30':{'Agenda Programada':1},'31':{'Escritorio Judicial':1},'32':{'Motor Tramitaci�n':1},'33':{'Motor Tramitaci�n':1},'34':{'Motor Tramitaci�n':1},'35':{'Editor documentos':1},'36':{'Motor Tramitaci�n':1},'37':{'Editor documentos':1},'38':{'Escritorio Judicial':1},'40':{'Motor Tramitaci�n':1},'41':{'Motor Tramitaci�n':1},'42':{'Motor Tramitaci�n':1},'43':{'Escritorio Judicial':1},'44':{'Motor Tramitaci�n':1},'45':{'Motor Tramitaci�n':1},'46':{'Motor Tramitaci�n':1},'49':{'Editor documentos':1},'51':{'Gesti�n y Administraci�n':1},'53':{'Agenda Calendario':1},'57':{'Editor documentos':1},'58':{'Gesti�n y Administraci�n':1},'59':{'Motor Tramitaci�n':1},'60':{'Ejecutorias':1},'61':{'Ejecutorias':1},'62':{'Gesti�n y Administraci�n':1},'63':{'Escritorio Judicial':1},'66':{'Gesti�n EJE':1},'67':{'Gesti�n y Administraci�n':1},'69':{'Gesti�n y Administraci�n':1},'70':{'Gesti�n y Administraci�n':1},'73':{'Integraci�n Lexnet':1},'74':{'Integraci�n Lexnet':1},'75':{'Motor Tramitaci�n':1},'76':{'Motor Tramitaci�n':1},'77':{'Editor documentos':1},'78':{'Motor Tramitaci�n':1},'81':{'Portafirmas':1},'82':{'Procedimientos ETL Migraci�n':1},'83':{'Registro y Reparto':1},'84':{'Registro y Reparto':1},'85':{'Motor Tramitaci�n':1}};
const ROUTING_PRIOR={'NUEVO ADRIANO':{'M�laga':{'2_Gestion_Cierre':0.424,'DevOps':0.254,'Basal Adriano':0.172,'1_Pendiente_Usuario':0.046,'Adriano':0.04,'SPU-CRIP':0.03,'Gestion de Usuarios':0.007,'Formaci�n':0.007,'Procesal':0.006,'Garant�a Adriano':0.005,'Cambio':0.002,'DP_Malaga':0.002,'Centro de  Servicio al Usuario':0.002,'VDI':0.001,'Planificacion':0.001},'Sevilla':{'2_Gestion_Cierre':0.469,'Basal Adriano':0.198,'DevOps':0.191,'Adriano':0.06,'1_Pendiente_Usuario':0.033,'SPU-CRIP':0.016,'Procesal':0.015,'Gestion de Usuarios':0.006,'Formaci�n':0.003,'Garant�a Adriano':0.002,'SACOEP-Explotacion':0.001,'RPA':0.001,'Nueva Sede':0.001,'Help-Desk':0.001,'Centro de  Servicio al Usuario':0.001,'Cambio':0.001},'Granada':{'2_Gestion_Cierre':0.476,'DevOps':0.21,'Basal Adriano':0.195,'Adriano':0.055,'1_Pendiente_Usuario':0.04,'Formaci�n':0.009,'Gestion de Usuarios':0.006,'Garant�a Adriano':0.003,'Cambio':0.002,'Procesal':0.002,'SPU-CRIP':0.002,'NUMO':0.002},'C�diz':{'2_Gestion_Cierre':0.45,'DevOps':0.221,'Basal Adriano':0.196,'Adriano':0.058,'1_Pendiente_Usuario':0.032,'SPU-CRIP':0.017,'Formaci�n':0.016,'Gestion de Usuarios':0.005,'Procesal':0.002,'Planificacion':0.002,'Help-Desk':0.002},'Almer�a':{'2_Gestion_Cierre':0.41,'DevOps':0.214,'Basal Adriano':0.185,'Adriano':0.07,'1_Pendiente_Usuario':0.059,'Garant�a Adriano':0.023,'Formaci�n':0.011,'Gestion de Usuarios':0.009,'Procesal':0.007,'SPU-CRIP':0.005,'Help-Desk':0.005,'NUMO':0.002,'DNoA':0.002},'Ja�n':{'2_Gestion_Cierre':0.463,'DevOps':0.263,'Basal Adriano':0.153,'1_Pendiente_Usuario':0.053,'Adriano':0.03,'SPU-CRIP':0.017,'DP_Jaen':0.007,'NUMO':0.003,'Gestion de Usuarios':0.003,'Formaci�n':0.003,'Procesal':0.003},'C�rdoba':{'2_Gestion_Cierre':0.478,'DevOps':0.247,'Basal Adriano':0.182,'Adriano':0.027,'1_Pendiente_Usuario':0.027,'Formaci�n':0.007,'Gestion de Usuarios':0.007,'Procesal':0.007,'NUMO':0.003,'Help-Desk':0.003,'SPU-CRIP':0.003,'Cambio':0.003,'DP_Cordoba':0.003},'Huelva':{'2_Gestion_Cierre':0.453,'DevOps':0.215,'Basal Adriano':0.194,'Adriano':0.069,'1_Pendiente_Usuario':0.04,'SPU-CRIP':0.016,'Formaci�n':0.008,'Fujitsu (ARCONTE)':0.004}},'PUESTO DE TRABAJO':{'Sevilla':{'SPU-CRIP':0.576,'2_Gestion_Cierre':0.244,'GM Techonology':0.051,'Deleg_Sev':0.029,'Microinformatica':0.029,'DP_Viapol':0.023,'DP_Sevilla':0.012,'GTSW':0.004,'SACOEP-Gproyectos':0.004,'Centro de  Servicio al Usuario':0.004,'VDI':0.004,'Planificacion':0.003,'Inventario':0.002,'SOLUTIA':0.002,'VPN Port�tiles':0.002,'TEKNOSERVICE':0.001,'1_Pendiente_Usuario':0.001,'GTSR':0.001,'1_Pendientes_causa_externa':0.001,'SADESI':0.001,'Gestion de Usuarios':0.001,'Control_Remedy':0.001,'SACOEP-ESP_Nuevoadriano':0.001,'Suministros':0.001,'Desarrollo':0,'Basado-Sevilla':0,'SADESI-Correo':0,'Formaci�n':0,'RPA':0,'SACOEP-DICIREG':0,'Puesto de Trabajo':0,'Coordinaci�n':0,'SACOEP-Coordinacion':0,'Pte Causa Externa CSU':0,'DevOps':0},'M�laga':{'SPU-CRIP':0.641,'2_Gestion_Cierre':0.209,'GM Techonology':0.068,'Microinformatica':0.028,'DP_Malaga':0.018,'SV_CJ_Malaga':0.009,'Centro de  Servicio al Usuario':0.005,'VDI':0.003,'VPN Port�tiles':0.003,'Gestion de Usuarios':0.002,'TEKNOSERVICE':0.002,'1_Pendiente_Usuario':0.002,'Planificacion':0.002,'GTSW':0.002,'GTSR':0.001,'SACOEP-Gproyectos':0.001,'SADESI-Correo':0.001,'SOLUTIA':0.001,'Inventario':0.001,'SADESI':0,'Suministros':0,'Formaci�n':0},'C�diz':{'SPU-CRIP':0.477,'DP_Cadiz':0.224,'2_Gestion_Cierre':0.175,'GM Techonology':0.073,'Microinformatica':0.029,'Centro de  Servicio al Usuario':0.005,'VDI':0.003,'SACOEP-Gproyectos':0.002,'Gestion de Usuarios':0.002,'Planificacion':0.001,'Suministros':0.001,'SADESI-Correo':0.001,'GTSR':0.001,'SOLUTIA':0.001,'1_Pendientes_causa_externa':0,'1_Pendiente_Usuario':0,'Inventario':0,'Formaci�n':0,'TEKNOSERVICE':0},'Granada':{'SPU-CRIP':0.534,'2_Gestion_Cierre':0.292,'DP_Granada':0.068,'GM Techonology':0.053,'Microinformatica':0.026,'Centro de  Servicio al Usuario':0.007,'1_Pendiente_Usuario':0.005,'SACOEP-Gproyectos':0.003,'VDI':0.003,'VPN Port�tiles':0.002,'GTSR':0.002,'Planificacion':0.002,'SOLUTIA':0.001,'GTSW':0.001,'Help-Desk':0.001,'Gestion de Usuarios':0.001,'TEKNOSERVICE':0.001,'SACOEP-Puestotrabajo':0.001,'LEXMARK IMPRESORAS':0.001,'SADESI-Correo':0.001,'Inventario':0.001},'C�rdoba':{'DP_Cordoba':0.341,'SPU-CRIP':0.264,'2_Gestion_Cierre':0.244,'GM Techonology':0.066,'Microinformatica':0.035,'VDI':0.01,'1_Pendiente_Usuario':0.007,'GTSW':0.007,'SACOEP-Gproyectos':0.005,'Centro de  Servicio al Usuario':0.004,'Planificacion':0.003,'Gestion de Usuarios':0.003,'TEKNOSERVICE':0.002,'Inventario':0.002,'Puesto de Trabajo':0.002,'GTSR':0.002,'SADESI':0.001,'SOLUTIA':0.001,'Coordinaci�n':0.001},'Ja�n':{'SPU-CRIP':0.551,'2_Gestion_Cierre':0.176,'DP_Jaen':0.16,'GM Techonology':0.053,'Microinformatica':0.035,'VDI':0.005,'Centro de  Servicio al Usuario':0.004,'Inventario':0.003,'SACOEP-Gproyectos':0.003,'Gestion de Usuarios':0.003,'SOLUTIA':0.002,'Planificacion':0.001,'GTSR':0.001,'GTSW':0.001,'TEKNOSERVICE':0.001},'Huelva':{'SPU-CRIP':0.496,'DP_Huelva':0.191,'2_Gestion_Cierre':0.167,'GM Techonology':0.094,'Microinformatica':0.026,'TEKNOSERVICE':0.007,'Centro de  Servicio al Usuario':0.007,'SACOEP-Gproyectos':0.005,'SOLUTIA':0.003,'1_Pendiente_Usuario':0.002,'VDI':0.001,'GTSW':0.001},'Almer�a':{'DP_Almeria':0.326,'SPU-CRIP':0.316,'2_Gestion_Cierre':0.258,'GM Techonology':0.059,'Microinformatica':0.014,'Centro de  Servicio al Usuario':0.011,'VDI':0.006,'GTSW':0.002,'1_Pendiente_Usuario':0.002,'Inventario':0.001,'SOLUTIA':0.001,'GTSR':0.001,'DevOps':0.001,'SADESI-Correo':0.001,'VPN Port�tiles':0.001}}};
const KW_PROFILES={'1.1':['sentencias','sentencia','mero','numerador','numeraci','nig','objeto','definitivo','contador','auto','numero','registrada'],'1':['numerador','salto','sentencia','salta','sentencias','numerico','arreglo','contador','mero','auto','numero','corresponde'],'2':['contador','aceptadas','repetidos','saltado','ejecuciones','mero','aceptado','ejecuci','registrado','pasado','correspondido','extranjero'],'2.1':['numerador','numeradores','incoado','nig','mero','ejecuciones','numero','etj','driano','duplicadas','registradas','asigne'],'3':['salto','procedural','estadistica','huecos','provoque','wue','acabo','numeraor','contadcor','fallecido','temor','registada'],'4':['ejecutoiras','convicci','ultima','intercambio','creada','numeros','seria','piezas','vamos','grabar','xima','salto'],'6':['diligencis','festivo','prision','recurriendo','p13','reactivacion','quieren','elre','necesidad','generar','elevado','enviarlo'],'6.2':['desbloquear','nig','bloqueado','necesito','estado','terminado','transformaci','trabajar','desbloqueo','rojo','poder','otro'],'6.3':['nig','itinerado','desbloquear','bloqueado','devuelto','penal','desbloqueo','driano','itine','remitido','trabajar','error'],'6.1':['acumulaci','acumulado','desbloquear','nig','acumulacion','bloqueado','terminado','desbloqueo','trabajar','necesito','dacu','error'],'6.4':['desbloquear','nig','transformaci','transformado','abreviado','original','pab','retrotraer','dip','proa','trproc','error'],'7':['asignar','asignarlo','error','nig','asignarle','visor','demanda','aceptado','clase','driano','permite','adriano'],'8':['normas','reparto','oficio','reducci','juzgados','lleve','secccion','email','demandas','modificacion','solicitado','cabo'],'9':['proveer','escritos','escrito','pendientes','nig','pendiente','proveido','proveidos','prove','acumulado','proveerlos','porque'],'10':['recurso','asociado','devolver','operaci','apelaci','devoluci','realizar','rrec','origen','malaga','contencioso','hacer'],'11':['cteaje','tablas','alegaci','sscc','proy','oojj','regulado','activos','garantizar','cuota','hij','periodo'],'12':['pico','dru','recibidos','encuadra','cumplimentado','ejh','categor','ninguna','devuelto','enviado','aparece','aceptar'],'14':['rqe','asuntoshistoriaentity','timeline','blanco','time','desaparecido','encontrado','line','capturas','queja','nig','adriano'],'15':['incoa','procedimineto','hacer','caso','error','adriano','organo','nig','2906744s20130005436','confirmado','jct','2906742c20030002725'],'16':['consolidar','consolidaci','consolidacion','intentado','nig','consolida','laj','elevar','traslado','puedan','consolidado','remitir'],'17':['recurso','elevar','audiencia','rellenar','apelaci','acontecimiento','elevado','puedo','apelac','porque','irec','nig'],'18':['nig','error','anular','necesito','resolvemos','incoado','registro','pieza','porque','numero','cierra','cancelen'],'19':['atestados','guardia','horas','lexnet','polic','entran','atestado','entrado','entrada','tiempo','muchas','ejemplos'],'20':['altobex','fiscal','equivado','nig1101242120240003465','remota','cancelarlo','ilegible','darles','adopci','pertenecen','bdias','funcamentaci'],'21':['quedado','ejecuci','borrarlo','nig','firmado','eliminar','documento','auto','deja','providencia','eliminarlo','borrar'],'22':['transformar','tipos','transformaci','encontrado','trproc','abreviado','salta','nig','necesito','acordadon','defensor','pretendo'],'23':['rechazar','escritos','aceptar','aceptarlo','escrito','pendientes','bandeja','proveido','quiero','presentado','rechazado','pueden'],'24':['acumular','acumulacion','acumulaci','acumulador','acumularlo','acup','acumuladas','error','acontecimiento','mismo','hacer','nig'],'25':['nig','trabajar','acceder','asunto','digital','regeneraci','modernizaci','infraestructuras','contacto','cerramos','sistemas','centro'],'26':['trproc','realizra','cancelada','encontrados','lote','gestionar','conversion','documentos','firma','hacer','nig','pertenece'],'27':['asignar','visor','invocar','recibiendo','error','indicado','nig','producido','contenido','mensaje','existe','uri'],'28':['capturade','ofice','open','comuniquen','solicitadas','vuelvo','comunicacion','contestador','pantallas','cau15','persiste','obstante'],'29':['bandeja','civil','pasados','trasladen','penal','penales','encuentran','pantallazo','ruego','asuntos','respuesta','repite'],'30':['reserva','itinerar','ojade','celebrado','sala','celebro','celebrada','pendiente','dip','salas','cancelar','nig'],'31':['aceptado','asignar','bandeja','asuntos','aceptar','pendientes','nig','asunto','error','adriano','vuelvan','registro'],'32':['secreto','sumario','levantar','trabajarlo','fiscal','levant','fueran','india','desbloquedo','expedinte','restringido','descloqueen'],'33':['pertenece','organo','itine','itinerar','asunto','otro','judicial','dice','programa','instrucci','itineracion','necesito'],'34':['tipo','consecutivo','mma','ninguan','subtipo','condenatoria','aunso','curatela','tef','squeda','convertirlo','seguridad'],'35':['documentos','fallado','editor','servidor','visualizar','stxwordeditorticketer','adriano','conexi','ngase','proporcionando','contacto','abrir'],'36':['esquema','definido','procesal','incoa','trabajar','expediente','recuerdo','2906743p20140053239','supuestos','cumplimentaci','sureactivaci','normalmente'],'37':['borrador','firmado','firmada','documento','aparece','firma','nig','sentencia','decreto','captura','driano','adjuntamso'],'38':['aceptar','encuentra','origen','asuntos','nig','itineraci','aceptarlo','reparto','asunto','leer','permite','bandeja'],'40':['sije','upad','intervenci','nig','etj','origen','ejido','organo','ejecuci','procesal','encuentra','hacer'],'41':['nig','mismo','repetir','eleve','tramitemos','registralo','enlazado','diferentes','dimanante','procedente','distintos','impide'],'42':['ocurrido','enviar','rogar','arroja','cifras','2105441c19981000303','tramitados','espero','solucionaran','rfavor','in0000002408253','firma'],'43':['aceptar','escritos','escrito','rechazar','uuid','pendientes','encontrado','bandeja','aceptarlo','rechazarlo','error','incorporar'],'44':['intervinientes','adir','domicilio','editar','nuevos','modificar','pesta','datos','letrados','1101543p20100001987','intervineinete','aparecerl'],'45':['t304006795','reposici','informativo','comunicarnos','obstante','persiste','cau13','resuelve','hice','xito','eficacia','archivado'],'46':['firma','algo','todas','error','nuamente','encima','lentitud','comuniquemos','copiandola','server','angustias','sima'],'47':['trae','upad','titulo','asociado','origen','monitorio','ejecuci','documentos','mero','judicial','nig'],'49':['nig','reparto','documento','resolver','numero','documentos','ajusta','enumeracion','in0000002427769','inhibilitado','casualmente','recibio'],'51':['sala','ojade','vistas','salas','arconte','videos','habiliten','reserva','juicios','alar','tenian','ojades'],'53':['tareas','asignadas','tarea','negociado','aparecen','aunque','marcador','inicial','vuelcan','panel','comentarios','grabe'],'56':['taine','existiendo','acumuladas','pto','abril','carpeta','constan','line','abrevia','documentos','sale'],'57':['documento','documentos','editar','generar','dior','contenido','tienen','hacer','nig','comprobamos','aparece','crear'],'58':['acceso','perfil','plazas','adriano','plaza','tribunal','instancia','driano','alta','tengo','acceder','consultas'],'59':['altobex','incorporar','adriano','jpeg','compatible','subidos','abrimos','incoporado','adjuntada','incluyeron','guia','abrebiado'],'60':['ndome','zaguilarf','llamarnos','indiquemos','buscador','suelen','ejecuciones','etj','queremos','numerar','diferente','sabemos'],'61':['incoado','haberse','epe','ejecutoria','eliminar','lev','penal','error','nig'],'62':['sincronizaci','puestos','temis','necesidad','asignamos','manual','otros','rgano','ade','traslado','cargo','alta'],'63':['acciones','nig','asociado','registrar','rechazar','indicando','manualmente','0490242c20120005063','registras','informatico','desconocemos','asutos'],'66':['descargar','celebraron','xml','ficheros','1808742c20140025289','consolidan','observa','firmados','pantallazos','distintos','enjuiciamiento','esas'],'67':['titular','sustituto','juez','cabecera','cargo','magistrada','jueza','sustituta','aparece','ponga','instancia','desplegable'],'68':['docuemnetos','enlotable','lote','dice','trabajar','asunto','deja'],'69':['firmar','firmante','titular','juez','magistrada','perfil','penal','aparece','mccastilloa','mozo','manzano','termine'],'70':['whitelabel','documentos','acceder','alta','driano','apartado','permisos','normalizada','tramita','error','visualizar','traslado'],'73':['viene','mancha','aceder','castilla','comunidades','in0000002412675','idlexnet','gabinete','solventado','dicos','guardias','lexnet'],'74':['lexnet','notificaciones','notificar','procuradores','anulado','rpl','nig','reenv','puedo','mismo','escritos','error'],'75':['eml','fraccione','zip','elimianr','incorporarla','capacidad','cuantas','debida','archivos','grabaci','formato','prueba'],'76':['exhorto','exhortos','devolver','acumular','primeras','enviar','adriano','reparto','telem','primera','realizar','error'],'77':['telefonos','blanco','diario','obtener','email','carpeta','visualizar','separada','numeraci','podido','crear','pantallazo'],'78':['fsaec','urgentes','penal','dur24','turnarla','efectos','remitirla','signo','sentencia','resuelve','constar','fsae'],'81':['firmar','portafirmas','error','documentos','certificado','perfectamente','certificiado','hacemos','cancelados','luis','digitalmente','pdtes'],'82':['migrado','encontrarse','migrada','adriando','separaci','0490242c20100003912','matrimonial','scace','testimonio','procedentes','ejecuci','devueltos'],'83':['repartir','reparto','repartido','nig','registro','remitido','penal','procesado','asunto','repartirse','error','juzgados'],'84':['demandas','nig','registro','registrar','asunto','jurisdicci','reparto','declarativas','repartidas','ryr','ruega','ejecutivas'],'85':['interviniente','intervinientes','eliminar','duplicado','nig','repetido','uno','pab','porque','borrar','recurso','julen'],'86':['hcv','sigue','parte','diario','correo']};
const TRAINING_STATS={labeledCases:3130,uniqueTipos:14,uniqueCasos:80,casosWithDesc:78,routingEntries:18787};

function predictCaseV2(desc, tipo, clase, provincia) {
  if (!tipo && !desc && !clase) return null;
  const descLower = (desc||'').toLowerCase().replace(/[^a-záéíóúñü0-9\s]/g,'');
  const isNA = clase && clase.toLowerCase().includes('nuevo adriano');

  // For non-Adriano: use routing matrix directly, no keyword matching against cases
  if (!isNA) {
    let routedGrupo = null, routingConf = 0;
    if (ROUTING_PRIOR[clase] && provincia && ROUTING_PRIOR[clase][provincia]) {
      const provData = ROUTING_PRIOR[clase][provincia];
      const entries = Object.entries(provData).sort((a,b) => b[1]-a[1]);
      routedGrupo = entries[0][0];
      routingConf = +(entries[0][1] * 100).toFixed(1);
    }
    // If no routing match by province, get top overall for this clase
    if (!routedGrupo && ROUTING_PRIOR[clase]) {
      const allProvs = Object.values(ROUTING_PRIOR[clase]);
      const globalCounts = {};
      for (const pData of allProvs) {
        for (const [g, p] of Object.entries(pData)) {
          globalCounts[g] = (globalCounts[g]||0) + p;
        }
      }
      const entries = Object.entries(globalCounts).sort((a,b) => b[1]-a[1]);
      if (entries.length) {
        routedGrupo = entries[0][0];
        routingConf = +(entries[0][1] / allProvs.length * 100).toFixed(1);
      }
    }
    // Determine synthetic caso for non-NA
    let caso = '—';
    if (clase) {
      if (clase.toLowerCase().includes('puesto')) caso = 'PT';
      else if (clase.toLowerCase().includes('infraestructura')) caso = 'SI';
      else if (clase.toLowerCase().includes('gestion')) caso = 'GU';
      else if (clase.toLowerCase().includes('comunicaciones')) caso = 'COM';
      else if (clase.toLowerCase().includes('aplicaciones')) caso = 'AP';
      else if (clase.toLowerCase().includes('grabacion')) caso = 'GV';
      else if (clase.toLowerCase().includes('formacion') || clase.toLowerCase().includes('formativo')) caso = 'SF';
      else if (clase.toLowerCase().includes('inventario')) caso = 'INV';
      else if (clase.toLowerCase().includes('seguridad')) caso = 'SEG';
      else if (clase.toLowerCase().includes('suministro')) caso = 'SUM';
      else caso = clase;
    }
    return {
      caso,
      confianza: routingConf,
      grupo: routedGrupo || '—',
      breakdown: { routing: routingConf },
      routing: routedGrupo || '—',
      alternativas: [],
      isNA: false
    };
  }

  // For NUEVO ADRIANO: full predictor with TIPO prior + keywords + routing
  const scores = {}, breakdown = {};

  // 1. TIPO prior
  const tipoKey = Object.keys(TIPO_PRIOR).find(k => tipo && k.toLowerCase().includes(tipo.toLowerCase()));
  if (tipoKey) {
    const data = TIPO_PRIOR[tipoKey];
    const totalP = Object.values(data).reduce((a,b) => a + b, 0);
    for (const [c, p] of Object.entries(data)) {
      scores[c] = (scores[c]||0) + p/totalP * 0.65;
      if (!breakdown[c]) breakdown[c] = {};
      breakdown[c].tipo = +(p * 100).toFixed(1);
    }
  }

  // 2. Keyword match
  for (const [c, words] of Object.entries(KW_PROFILES)) {
    let match = 0;
    for (const w of words) {
      if (descLower.includes(w)) match++;
    }
    if (match > 0) {
      const kw = match / words.length * 0.25;
      scores[c] = (scores[c]||0) + kw;
      if (!breakdown[c]) breakdown[c] = {};
      breakdown[c].kw = +(kw * 100).toFixed(1);
    }
  }

  // 3. Routing context bonus
  if (ROUTING_PRIOR['NUEVO ADRIANO'] && provincia && ROUTING_PRIOR['NUEVO ADRIANO'][provincia]) {
    const provData = ROUTING_PRIOR['NUEVO ADRIANO'][provincia];
    const topGrupo = Object.entries(provData).sort((a,b) => b[1]-a[1])[0];
    if (topGrupo) {
      const matching = Object.keys(CASO_TIPO).find(c =>
        topGrupo[0].includes(c)
      );
      if (matching) {
        scores[matching] = (scores[matching]||0) + topGrupo[1] * 0.1;
        if (!breakdown[matching]) breakdown[matching] = {};
        breakdown[matching].routing = +(topGrupo[1] * 10).toFixed(1);
      }
    }
  }

  // Rank
  const ranked = Object.entries(scores)
    .sort((a,b) => b[1]-a[1])
    .slice(0,5)
    .map(([c,s]) => ({ caso:c, score:+(s*100).toFixed(1), breakdown:breakdown[c]||{} }));

  if (!ranked.length) return null;

  const top = ranked[0];
  const topCaso = top.caso;

  // Grupo: for NA entries, prefer routing if available, fallback to CASE_DEFS
  let routedGrupo = null;
  if (ROUTING_PRIOR['NUEVO ADRIANO'] && provincia && ROUTING_PRIOR['NUEVO ADRIANO'][provincia]) {
    const provData = ROUTING_PRIOR['NUEVO ADRIANO'][provincia];
    routedGrupo = Object.entries(provData).sort((a,b) => b[1]-a[1])[0][0];
  }
  let defGrupo = null;
  if (typeof CASE_DEFS !== 'undefined') {
    const def = CASE_DEFS.find(d => d.caso === topCaso);
    if (def) defGrupo = def.grupo;
  }

  return {
    caso: topCaso,
    confianza: top.score,
    grupo: routedGrupo || defGrupo || '—',
    breakdown: top.breakdown,
    routing: routedGrupo || '—',
    alternativas: ranked.slice(1).map(r => r.caso),
    isNA: true
  };
}
