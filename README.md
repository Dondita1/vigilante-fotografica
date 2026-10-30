# Vigilante externo de Fotográfica

Mira cada 10 minutos, desde GitHub Actions, si https://fotografica.codestudio.com.ar responde.
Es el aviso que llega justo cuando el servidor (isolutions) se cayó entero y el
diagnóstico de adentro (`diagnostico.mjs --vigilar`) ya no puede avisar.

- Se cae → un ntfy + un WhatsApp (plantilla `alerta_sistema`). Vuelve → otro aviso. No repite.
- El estado vive en el archivo `estado` del repo (ok / caido); el workflow lo commitea cuando cambia.
- Secretos: `NTFY_TOPIC`, `WA_TOKEN`, `WA_TELEFONO_ID`, `WA_DESTINO`. Se cargan desde la compu de Mateo con
  `sh herramientas/alertas-externas.sh` del repo grafica-sistema (los saca del servidor, sin mostrarlos).
- Repo público a propósito: los repos públicos no gastan minutos de Actions. No hay nada secreto en el código.
- Reemplaza al vigilante que vivía en el VPS de Hostinger (31.97.253.184), caído desde el 30/10/2026.
- Probar a mano: pestaña Actions → vigilar → Run workflow.
