# Cuentas, roles y auditoría del calendario web

Esta versión añade gestión de cuentas y registro de cambios al calendario
desplegado en Vercel.

## Roles

- **`admin`**: control total. Puede editar cualquier parte del calendario
  (clima, separadores/franjas horarias, meses, estaciones, etc.) **y**
  acceder al panel "Administración" para crear/editar/eliminar cuentas y
  ver el historial de cambios.
- **`profesor`**: sólo puede:
  - Añadir o editar **clases** dentro de las franjas horarias existentes.
  - Añadir o editar **eventos por franja** (bloque amarillo encima de
    cada franja).
  - Interactuar con el panel de **notas** (tablón, normas, optativas,
    clubes, boletín de notas).

  Aunque manualmente envíe un POST con cambios prohibidos, el backend
  los descarta y sólo aplica las partes permitidas (no es necesario que
  la web le esconda los botones).

## Variables de entorno necesarias en Vercel

Las que ya existían se mantienen:

| Variable               | Uso                                                         |
|------------------------|-------------------------------------------------------------|
| `DB_HOST`              | Host MySQL                                                  |
| `DB_USER`              | Usuario MySQL                                               |
| `DB_PASSWORD`          | Contraseña MySQL                                            |
| `DB_NAME`              | Base de datos (por defecto `cat_calendario`)                |
| `DB_PORT`              | Puerto (por defecto `3306`)                                 |
| `DB_SSL`               | `true` para activar SSL                                     |
| `JWT_SECRET`           | Secreto para firmar los JWT del calendario web              |
| `CAT_CAL_SYNC_SECRET`  | Token compartido con GMod para syncs (`X-CatCal-Sync-Token`)|

Y se añaden dos opcionales para el primer arranque:

| Variable                 | Uso                                                                      |
|--------------------------|--------------------------------------------------------------------------|
| `BOOTSTRAP_ADMIN_USER`   | Usuario admin que se creará automáticamente al primer login si la tabla `calendario_usuarios` está vacía. |
| `BOOTSTRAP_ADMIN_PASS`   | Contraseña inicial de ese admin.                                         |

> Una vez exista al menos un usuario en la tabla, las variables de
> bootstrap se ignoran completamente (no se puede usar el bootstrap para
> "resetear" un admin existente).

## Migración inicial (una sola vez)

La API crea las tablas `calendario_usuarios` y `calendario_logs` por sí
sola al primer uso. Si quieres prepararlas a mano (recomendado al
desplegar), ejecuta `sql/migrations.sql` contra tu base de datos MySQL.

```sql
-- desde tu cliente de MySQL
SOURCE sql/migrations.sql;
```

## Cómo entrar la primera vez

1. Configura `BOOTSTRAP_ADMIN_USER` y `BOOTSTRAP_ADMIN_PASS` en Vercel.
2. Abre la web, pulsa "Iniciar sesión" y entra con esas credenciales.
3. Aparecerá el botón **⚙️ Administración** arriba a la derecha. Ábrelo
   y crea las cuentas reales (admins y profesores).
4. *(Recomendado)* Borra `BOOTSTRAP_ADMIN_USER` y `BOOTSTRAP_ADMIN_PASS`
   de Vercel cuando ya tengas al menos un admin "real" creado.

## Endpoints

| Método | Ruta                                   | Quién  | Descripción                                |
|--------|----------------------------------------|--------|--------------------------------------------|
| POST   | `/api/login`                            | todos  | Devuelve JWT + rol                          |
| GET    | `/api/verificar`                        | todos  | Comprueba el token y devuelve rol/usuario   |
| GET    | `/api/calendario`                       | todos  | Lee el calendario                           |
| POST   | `/api/calendario`                       | rol    | Guarda el calendario (admin: todo / prof.: filtrado) |
| GET    | `/api/usuarios`                         | admin  | Lista usuarios (sin contraseñas)            |
| POST   | `/api/usuarios`                         | admin  | Crea usuario                                |
| PUT    | `/api/usuarios?username=xxx`            | admin  | Cambia contraseña y/o rol                   |
| DELETE | `/api/usuarios?username=xxx`            | admin  | Elimina usuario                             |
| GET    | `/api/logs?limit=&offset=&q=&desde=&hasta=` | admin | Audita cambios                          |

## Auditoría

Cada vez que un usuario web (admin o profesor) guarda cambios en el
calendario, o un admin crea/modifica/borra cuentas, se inserta una fila
en `calendario_logs` con:

- `fecha` (timestamp del servidor)
- `username` y `rol` del autor
- `accion` ("Editar calendario", "Crear usuario", etc.)
- `detalles` (resumen humano: "semanas 1, notas, tablón")

Las syncs masivas desde GMod (header `X-CatCal-Sync-Token`) **no se
registran** en el log para evitar saturarlo.
