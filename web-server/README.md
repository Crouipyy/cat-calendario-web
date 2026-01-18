# Servidor Web del Calendario

Este servidor web permite acceder al calendario desde internet y sincronizarlo con el servidor de FiveM.

## Instalación

1. Instalar dependencias:
```bash
npm install
```

2. Configurar variables de entorno (opcional):
```bash
export PORT=3000
export JWT_SECRET=tu_secreto_super_seguro
```

3. Iniciar servidor:
```bash
npm start
```

O en modo desarrollo:
```bash
npm run dev
```

## Uso

- **Calendario público**: `http://localhost:3000/web`
- **API REST**: `http://localhost:3000/api`

## Autenticación

Por defecto se crea un usuario:
- Usuario: `admin`
- Contraseña: `admin123`

**IMPORTANTE**: Cambiar la contraseña en producción editando `users.json` o usando bcrypt para generar un hash nuevo.

## Endpoints API

- `GET /api/calendario` - Obtener calendario (público)
- `POST /api/calendario` - Guardar calendario (requiere autenticación)
- `GET /api/config` - Obtener configuración (público)
- `POST /api/login` - Iniciar sesión
- `GET /api/verificar` - Verificar token

