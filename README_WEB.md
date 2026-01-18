# Calendario Escolar - Versión Web

Este calendario ahora puede ser accesible desde internet y sincronizarse automáticamente con el servidor de FiveM.

## Características

✅ **Acceso desde Internet**: Los usuarios pueden ver el calendario desde cualquier navegador  
✅ **Edición desde Web**: Usuarios con permisos pueden editar el calendario desde internet  
✅ **Sincronización Automática**: Los cambios se reflejan tanto en el juego como en la web  
✅ **Autenticación**: Sistema de login para controlar quién puede editar  
✅ **Modo Dual**: Funciona tanto dentro del juego como en navegadores web  

## Estructura del Proyecto

```
cat_calendario/
├── client/              # Código del cliente FiveM
├── server/              # Código del servidor FiveM
├── nui/                 # Interfaz HTML/CSS/JS (compartida)
├── web-server/          # Servidor web Node.js
│   ├── server.js        # Servidor Express
│   ├── package.json    # Dependencias Node.js
│   └── users.json      # Usuarios (se crea automáticamente)
├── config.lua          # Configuración (incluye WebServer)
└── calendario_data.json # Datos del calendario (compartido)
```

## Inicio Rápido

### 1. Instalar Servidor Web

```bash
cd web-server
npm install
npm start
```

### 2. Configurar FiveM

Edita `config.lua` y configura:
```lua
Config.WebServer = {
    enabled = true,
    url = "http://TU_IP:3000",
    syncInterval = 30
}
```

### 3. Acceder

- **Desde el juego**: Como siempre, desde los puntos de interacción
- **Desde internet**: `http://TU_IP:3000/web`

## Uso

### Ver el Calendario (Sin Login)

Cualquier usuario puede ver el calendario sin necesidad de iniciar sesión. Solo accede a la URL del servidor web.

### Editar el Calendario (Requiere Login)

1. Accede a la URL del servidor web
2. Haz clic en "Iniciar Sesión" (aparece automáticamente si intentas editar sin estar logueado)
3. Ingresa tus credenciales
4. Una vez autenticado, podrás editar el calendario

### Credenciales por Defecto

- **Usuario**: `admin`
- **Contraseña**: `admin123`

⚠️ **Cambia estas credenciales en producción**

## Sincronización

El sistema sincroniza automáticamente:

1. **Desde el juego → Web**: Cuando un profesor guarda cambios en el juego, se actualizan en el archivo JSON que lee el servidor web
2. **Desde la web → Juego**: Cuando alguien guarda desde la web, el servidor de FiveM detecta los cambios periódicamente y actualiza a todos los jugadores

### Intervalo de Sincronización

Por defecto, el servidor de FiveM verifica cambios cada 30 segundos. Puedes ajustarlo en `config.lua`:

```lua
Config.WebServer.syncInterval = 60  -- Verificar cada 60 segundos
```

O desactivar la verificación automática (solo se actualizará al reiniciar el recurso):

```lua
Config.WebServer.syncInterval = 0
```

## Seguridad

### Cambiar Contraseña

1. Genera un hash bcrypt de tu nueva contraseña:
```javascript
const bcrypt = require('bcryptjs');
console.log(bcrypt.hashSync('tu_nueva_contraseña', 10));
```

2. Edita `web-server/users.json`:
```json
[
  {
    "username": "admin",
    "password": "TU_HASH_AQUI",
    "permisos": ["editar"]
  }
]
```

### Agregar Usuarios

Agrega más usuarios en `web-server/users.json`:

```json
[
  {
    "username": "admin",
    "password": "$2a$10$...",
    "permisos": ["editar"]
  },
  {
    "username": "profesor1",
    "password": "$2a$10$...",
    "permisos": ["editar"]
  },
  {
    "username": "lector",
    "password": "$2a$10$...",
    "permisos": []
  }
]
```

## API REST

El servidor web expone una API REST:

### Endpoints

- `GET /api/calendario` - Obtener calendario (público)
- `POST /api/calendario` - Guardar calendario (requiere autenticación)
- `GET /api/config` - Obtener configuración (público)
- `POST /api/login` - Iniciar sesión
- `GET /api/verificar` - Verificar token

### Ejemplo de Uso

```javascript
// Login
const response = await fetch('http://localhost:3000/api/login', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ username: 'admin', password: 'admin123' })
});
const { token } = await response.json();

// Guardar calendario
await fetch('http://localhost:3000/api/calendario', {
    method: 'POST',
    headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${token}`
    },
    body: JSON.stringify({ calendario: datosCalendario })
});
```

## Solución de Problemas

### El calendario no se actualiza en el juego

1. Verifica que `Config.WebServer.enabled = true`
2. Verifica que el intervalo de sincronización esté configurado
3. Reinicia el recurso: `restart cat_calendario`

### No puedo iniciar sesión

1. Verifica que `users.json` exista en `web-server/`
2. Verifica que el hash de la contraseña sea correcto
3. Revisa los logs del servidor web

### El servidor web no inicia

1. Verifica que Node.js esté instalado: `node --version`
2. Verifica que el puerto 3000 no esté en uso
3. Revisa los logs de error en la consola

## Producción

Para usar en producción:

1. **Usar HTTPS**: Configura nginx con SSL
2. **Cambiar credenciales**: No uses las credenciales por defecto
3. **Cambiar JWT_SECRET**: Usa un valor aleatorio seguro
4. **Firewall**: Solo abre los puertos necesarios
5. **PM2**: Usa PM2 para mantener el servidor corriendo

Ver `INSTALACION.md` para más detalles.

## Soporte

Si tienes problemas:

1. Revisa los logs del servidor web
2. Revisa los logs del servidor de FiveM (F8)
3. Verifica la configuración en `config.lua`
4. Verifica que el archivo `calendario_data.json` sea accesible

