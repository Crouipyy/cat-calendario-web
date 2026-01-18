# Guía de Instalación - Calendario Web

Esta guía te ayudará a configurar el calendario para que sea accesible desde internet y se sincronice con el servidor de FiveM.

## Requisitos

1. Node.js instalado (versión 14 o superior)
2. Servidor de FiveM funcionando
3. Acceso a internet para el servidor web

## Instalación del Servidor Web

1. **Navegar a la carpeta del servidor web:**
```bash
cd web-server
```

2. **Instalar dependencias:**
```bash
npm install
```

3. **Configurar el servidor:**
   - Edita `server.js` si necesitas cambiar el puerto (por defecto: 3000)
   - Cambia `JWT_SECRET` en `server.js` por un valor seguro en producción

4. **Iniciar el servidor:**
```bash
npm start
```

O en modo desarrollo (con auto-reload):
```bash
npm run dev
```

## Configuración del Servidor de FiveM

1. **Editar `config.lua`:**
   - Busca la sección `Config.WebServer`
   - Configura la URL del servidor web:
     ```lua
     Config.WebServer = {
         enabled = true,
         url = "http://TU_IP_PUBLICA:3000", -- Cambiar por tu IP pública
         syncInterval = 30, -- Sincronización automática cada 30 segundos
         apiKey = "" -- Opcional
     }
     ```

2. **Reiniciar el recurso:**
```bash
restart cat_calendario
```

## Acceso al Calendario

### Desde el Servidor de FiveM
- Los jugadores pueden acceder al calendario como antes, desde los puntos de interacción en el juego.

### Desde Internet
- **URL pública:** `http://TU_IP_PUBLICA:3000/web`
- Cualquier usuario puede ver el calendario sin autenticación
- Para editar, necesitan iniciar sesión

## Autenticación

### Usuario por Defecto
- **Usuario:** `admin`
- **Contraseña:** `admin123`

**⚠️ IMPORTANTE:** Cambia la contraseña en producción editando `web-server/users.json` o usando bcrypt para generar un hash nuevo.

### Crear Nuevos Usuarios

1. **Editar `web-server/users.json`:**
```json
[
  {
    "username": "admin",
    "password": "$2a$10$...", // Hash bcrypt de la contraseña
    "permisos": ["editar"]
  },
  {
    "username": "profesor1",
    "password": "$2a$10$...",
    "permisos": ["editar"]
  }
]
```

2. **Generar hash de contraseña:**
   - Puedes usar un generador online de bcrypt
   - O usar Node.js:
   ```javascript
   const bcrypt = require('bcryptjs');
   const hash = bcrypt.hashSync('tu_contraseña', 10);
   console.log(hash);
   ```

## Sincronización

El calendario se sincroniza automáticamente:
- Cuando se guarda desde el juego → se actualiza en el servidor web
- Cuando se guarda desde el servidor web → se actualiza en el archivo JSON que lee el juego

**Nota:** El servidor web lee directamente el archivo `calendario_data.json`, por lo que los cambios se reflejan inmediatamente.

## Solución de Problemas

### El servidor web no inicia
- Verifica que el puerto 3000 no esté en uso
- Revisa que Node.js esté instalado correctamente
- Revisa los logs en la consola

### No se sincronizan los cambios
- Verifica que `Config.WebServer.enabled = true` en `config.lua`
- Verifica que la URL en `config.lua` sea correcta
- Asegúrate de que el servidor web esté accesible desde el servidor de FiveM

### No puedo iniciar sesión
- Verifica que `users.json` exista en `web-server/`
- Revisa que el hash de la contraseña sea correcto
- Revisa los logs del servidor web

## Seguridad

1. **Cambiar JWT_SECRET:** Usa un valor aleatorio y seguro
2. **Cambiar contraseñas por defecto:** No uses `admin123` en producción
3. **Usar HTTPS:** En producción, configura un proxy reverso (nginx) con SSL
4. **Firewall:** Solo abre el puerto necesario (3000) y restringe acceso si es posible
5. **API Key:** Considera agregar autenticación adicional con API key si es necesario

## Producción

Para usar en producción:

1. **Usar PM2 o similar:**
```bash
npm install -g pm2
pm2 start server.js --name calendario-web
pm2 save
pm2 startup
```

2. **Configurar nginx como proxy reverso:**
```nginx
server {
    listen 80;
    server_name tu-dominio.com;
    
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```

3. **Configurar SSL con Let's Encrypt:**
```bash
sudo certbot --nginx -d tu-dominio.com
```

