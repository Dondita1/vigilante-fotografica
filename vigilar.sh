#!/bin/bash
# Vigilante externo de Fotográfica (corre en GitHub Actions cada 10 min).
# Si https://fotografica.codestudio.com.ar deja de responder, avisa UNA vez por
# ntfy y por WhatsApp; cuando vuelve, avisa que volvió. El estado se guarda en la
# variable ESTADO del repo para no repetir el aviso cada 10 minutos.
# Secretos (Settings → Secrets): NTFY_TOPIC, WA_TOKEN, WA_TELEFONO_ID, WA_DESTINO.
set -u
URL="${URL:-https://fotografica.codestudio.com.ar/login}"
ANTES="${ESTADO_ANTES:-ok}"

probar() { curl -s -o /dev/null -m 15 -w '%{http_code}' "$URL" 2>/dev/null || echo "000"; }

codigo=$(probar)
if [ "$codigo" != "200" ]; then   # dos reintentos antes de darlo por caído
  sleep 20; codigo=$(probar)
  [ "$codigo" != "200" ] && { sleep 30; codigo=$(probar); }
fi
[ "$codigo" = "200" ] && AHORA=ok || AHORA="caido"
echo "$(date -u +%FT%TZ) respuesta=$codigo antes=$ANTES ahora=$AHORA"

ntfy() { # titulo texto prioridad tag
  [ -z "${NTFY_TOPIC:-}" ] && { echo "[sin NTFY_TOPIC] $1: $2"; return; }
  curl -s -m 15 -o /dev/null https://ntfy.sh/ -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg t "$NTFY_TOPIC" --arg ti "$1" --arg m "$2" --argjson p "$3" --arg g "$4" \
         '{topic:$t,title:$ti,message:$m,priority:$p,tags:[$g]}')" || echo "ntfy falló"
}
whatsapp() { # que arreglo  → plantilla alerta_sistema (es_AR), si falla texto suelto
  [ -z "${WA_TOKEN:-}" ] || [ -z "${WA_TELEFONO_ID:-}" ] || [ -z "${WA_DESTINO:-}" ] && { echo "[sin WhatsApp]"; return; }
  api="https://graph.facebook.com/v21.0/$WA_TELEFONO_ID/messages"
  r=$(curl -s -m 20 "$api" -H "Authorization: Bearer $WA_TOKEN" -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg to "$WA_DESTINO" --arg a "$1" --arg b "$2" \
      '{messaging_product:"whatsapp",to:$to,type:"template",template:{name:"alerta_sistema",language:{code:"es_AR"},components:[{type:"body",parameters:[{type:"text",text:$a},{type:"text",text:$b}]}]}}')")
  if ! echo "$r" | grep -q '"messages"'; then
    echo "plantilla no salió: $(echo "$r" | jq -r '.error.message // .' 2>/dev/null | head -c 200)"
    curl -s -m 20 -o /dev/null "$api" -H "Authorization: Bearer $WA_TOKEN" -H 'Content-Type: application/json' \
      -d "$(jq -cn --arg to "$WA_DESTINO" --arg t "⚠️ Fotográfica: $1 → $2" '{messaging_product:"whatsapp",to:$to,type:"text",text:{body:$t}}')"
  fi
}

if [ "$AHORA" != "$ANTES" ]; then
  if [ "$AHORA" = "caido" ]; then
    que="el servidor entero no responde desde internet (HTTP $codigo)"
    arreglo="ssh isolutions-vps · si no entra: panel DonWeb #5956922 → consola VNC (ufw status · systemctl restart ufw)"
    ntfy "Fotográfica · Sistema" "$que
→ $arreglo
(visto desde GitHub, el vigilante de afuera)" 4 rotating_light
    whatsapp "Sistema: $que" "$arreglo"
  else
    ntfy "Fotográfica · resuelto" "Volvió a andar: el servidor responde desde internet" 3 white_check_mark
    whatsapp "volvió a andar el servidor" "nada, ya está resuelto"
  fi
  # guardar el estado nuevo en la variable ESTADO del repo
  if ! gh api -X PATCH "repos/$GITHUB_REPOSITORY/actions/variables/ESTADO" -f name=ESTADO -f value="$AHORA" >/dev/null 2>&1; then
    gh api -X POST "repos/$GITHUB_REPOSITORY/actions/variables" -f name=ESTADO -f value="$AHORA" >/dev/null || echo "no pude guardar el estado"
  fi
  echo "aviso enviado: $ANTES → $AHORA"
else
  echo "sin cambios"
fi
