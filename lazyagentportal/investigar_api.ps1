<#
.SYNOPSIS
  Herramienta para investigar el protocolo WebSocket del Agent Portal OSCC.
  Uso: Abre Chrome, navega al portal, y captura todo el trafico WebSocket.

.DESCRIPTION
  Requiere dev-browser instalado.
  Ejecutar con: dev-browser --ignore-https-errors --timeout 120 run investigar_api.ps1

  Protocolo descubierto (OSCC Web V11.1.19):
  ───────────────────────────────────────────
  Formato mensaje: {"type":"1|2|0","data":{"realm":"N","type":"NN","data":{},"requestId":N}}
    type=1: Request (cliente->servidor)
    type=2: Response (servidor->cliente, incluye requestId)
    type=0: Event (servidor->cliente, push/suscripciones)

  Realms conocidos:
    0  = Login/Auth/Settings
    1  = User state
    2  = Media/Voice
    3  = Team/Queue
    4  = Activity log
    9  = System config
    13 = Agent team

  Realm 0 - Login flow:
    type=65 -> Server info (version, multiTenancy, SSO, etc)
    type=0  -> Login {locale, language, timezone, tenant, username, password}
    type=13 -> Settings/Config (load/save) con sub-tipos:
      504=CallHistory, 505=ForwardHistory, 511=AgentLogonMode
      517=PreferredDeviceLogonOption, 518=PreferredDeviceAlwaysUseThisDeviceId
      525=PreferredDeviceLastDeviceId, 564=ApfxTeamBar, 565=ApfxSpeedBar
      600=extension, 601-610=widget configs, 620-624=clipboard/video configs
    type=18 -> Get permissions
    type=20 -> Get auxiliary data
    type=43 -> Get contact list
    type=47 -> Get user state (routingState, mediaStates, handlingState)
    type=111-> Get something (returned empty array in test)
    type=125-> Get LDAP config

  Realm 2 - Media:
    type=25 -> Register device {number, isStaticONDActive}
    type=59 -> (unknown)
    type=60 -> Get extension info

  Realm 3 - Team/Queue:
    type=23 -> Event: Agent list update (full team state)
    type=31 -> Event: Queue/contact center statistics
    type=57 -> Tab tracking {tabId, opening}

  Realm 4 - Activity:
    type=24 -> Event: Activity log entries
    type=27 -> Get activity log

  Routing states: 0=EN_COLA, 1=OCUPADO, 2=REGISTRADO, 3=DESCONECTADO
  Presence states: 1=Disponible, 2=En pausa, 3=Ocupado, 4=Ausente
  Media types: 1=Voz, 2=Email, 3=Callback, 4=WebChat, 5=OpenMedia
  Media states: 0=Off, 1=On (logged in)
#>

# This script is a reference guide.
# To capture live traffic from this machine:
# 1. Open Chrome devtools (F12)
# 2. Navigate to Agent Portal and log in
# 3. Go to Network tab, filter by "WS"
# 4. Click on the WebSocket connection to see frames

Write-Host @"
INVESTIGACION DEL PROTOCOLO WEBSOCKET OSCC AGENT PORTAL
========================================================

El Agent Portal de OpenScape Contact Center (OSCC) v11.1.19
usa un protocolo JSON sobre WebSocket en:
  wss://hppcgroup.cccdm-rcja.juntadeandalucia.es/agentportal/ws/

NO expone una API REST tradicional. Todo el estado en tiempo
real (agentes, colas, llamadas) viaja por WebSocket.

Para capturar el trafico:
  1. Abre Chrome
  2. F12 -> Network -> WS
  3. Navega a $env:AGENT_PORTAL_WS
  4. Filtra por "agentportal/ws"
  5. Haz clic en la conexion y ve a la pestana "Messages"
  6. Ahi veras el JSON de ida y vuelta

COMANDOS PRACTICOS:
  dev-browser --ignore-https-errors --browser investigar run investigar_ws.js

"@
