# Depa Finder Web

Aplicación React para consumir el endpoint `GET /api/listings` del backend Phoenix y mostrar departamentos en una experiencia tipo Tinder con swipe izquierda/derecha.

## Requisitos

- Node.js 18+
- Variables de entorno:
  - `VITE_API_BASE_URL` (opcional, por defecto `http://localhost:4000`)
  - `VITE_GOOGLE_CLIENT_ID` (obligatorio para login)

## Scripts

```bash
npm install
npm run dev      # desarrollo
npm run build    # build de producción
npm run preview  # sirve el build
```

## Notas

- El listado se consume desde `${VITE_API_BASE_URL}/api/listings`.
- El login usa `@react-oauth/google`. Configura el Client ID en la consola de Google Cloud y colócalo en `VITE_GOOGLE_CLIENT_ID`.
- Los likes se almacenan en memoria del cliente; puedes persistirlos a futuro cuando exista un endpoint para matches/notas.
