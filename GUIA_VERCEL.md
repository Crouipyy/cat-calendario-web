# 🚀 Guía Completa: Subir Calendario a GitHub y Deploy en Vercel

Esta guía te llevará paso a paso desde cero hasta tener tu calendario funcionando en internet.

## 📋 Requisitos Previos

1. **Cuenta de GitHub** (gratis): https://github.com
2. **Cuenta de Vercel** (gratis): https://vercel.com
3. **Git instalado** en tu computadora (descarga: https://git-scm.com)

---

## 📦 Paso 1: Preparar el Proyecto para Vercel

### 1.1. Estructura de Carpetas

Tu proyecto debe tener esta estructura:

```
cat_calendario/
├── api/                    # Funciones serverless de Vercel
│   ├── calendario.js       # GET/POST /api/calendario
│   ├── login.js           # POST /api/login
│   ├── verificar.js       # GET /api/verificar
│   └── config.js          # GET /api/config
├── nui/                    # Interfaz web (HTML, CSS, JS)
│   ├── index.html
│   ├── script.js
│   ├── style.css
│   └── img/
├── web-server/             # (Opcional, para desarrollo local)
│   └── users.json
├── calendario_data.json    # Datos del calendario
├── vercel.json            # Configuración de Vercel
└── package.json           # Dependencias Node.js
```

### 1.2. Crear package.json en la raíz

Crea un archivo `package.json` en la raíz del proyecto:

```json
{
  "name": "cat-calendario-web",
  "version": "1.0.0",
  "description": "Calendario escolar accesible desde internet",
  "scripts": {
    "dev": "vercel dev"
  },
  "dependencies": {
    "jsonwebtoken": "^9.0.2",
    "bcryptjs": "^2.4.3"
  },
  "devDependencies": {
    "vercel": "^32.0.0"
  }
}
```

---

## 🔧 Paso 2: Configurar Git y GitHub

### 2.1. Inicializar Git (si no lo has hecho)

Abre una terminal en la carpeta del proyecto y ejecuta:

```bash
# Inicializar repositorio Git
git init

# Agregar todos los archivos
git add .

# Hacer commit inicial
git commit -m "Initial commit: Calendario web para Vercel"
```

### 2.2. Crear Repositorio en GitHub

1. Ve a https://github.com y haz clic en **"New repository"**
2. Nombre del repositorio: `cat-calendario-web` (o el que prefieras)
3. Descripción: "Calendario escolar accesible desde internet"
4. **NO marques** "Initialize with README" (ya tienes archivos)
5. Haz clic en **"Create repository"**

### 2.3. Conectar y Subir Código

GitHub te mostrará comandos. Ejecuta estos en tu terminal:

```bash
# Conectar con GitHub (reemplaza TU_USUARIO con tu usuario de GitHub)
git remote add origin https://github.com/TU_USUARIO/cat-calendario-web.git

# Cambiar a rama main (si es necesario)
git branch -M main

# Subir código a GitHub
git push -u origin main
```

**Si te pide autenticación:**
- Usa un **Personal Access Token** (no tu contraseña)
- Crea uno en: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
- Permisos: `repo` (acceso completo a repositorios)

---

## 🚀 Paso 3: Deploy en Vercel

### 3.1. Crear Cuenta en Vercel

1. Ve a https://vercel.com
2. Haz clic en **"Sign Up"**
3. Elige **"Continue with GitHub"** (más fácil)
4. Autoriza Vercel a acceder a tus repositorios

### 3.2. Importar Proyecto

1. En el dashboard de Vercel, haz clic en **"Add New..."** → **"Project"**
2. Busca tu repositorio `cat-calendario-web`
3. Haz clic en **"Import"**

### 3.3. Configurar Proyecto

Vercel detectará automáticamente que es un proyecto Node.js. Configura:

**Framework Preset:** Other (o deja en blanco)

**Root Directory:** `./` (raíz del proyecto)

**Build Command:** (deja vacío, no necesitas build)

**Output Directory:** (deja vacío)

**Install Command:** `npm install`

### 3.4. Variables de Entorno

Antes de hacer deploy, agrega variables de entorno:

1. Haz clic en **"Environment Variables"**
2. Agrega:
   - **Name:** `JWT_SECRET`
   - **Value:** (genera un valor aleatorio seguro, ejemplo: `mi_secreto_super_seguro_123456`)
   - **Environments:** Production, Preview, Development (marca todos)

3. Haz clic en **"Add"**

### 3.5. Deploy

1. Haz clic en **"Deploy"**
2. Espera 1-2 minutos mientras Vercel:
   - Instala dependencias
   - Construye el proyecto
   - Despliega las funciones serverless

### 3.6. ¡Listo!

Vercel te dará una URL como: `https://tu-proyecto.vercel.app`

**Tu calendario estará disponible en:**
- `https://tu-proyecto.vercel.app/web` - Calendario con modo web
- `https://tu-proyecto.vercel.app/api/calendario` - API REST

---

## ⚠️ IMPORTANTE: Limitación de Vercel

**Vercel no permite escribir archivos de forma persistente.** 

El sistema funciona así:
- ✅ **Web puede LEER** el calendario (desde el archivo del repositorio)
- ✅ **Web puede EDITAR** (pero solo en cache temporal)
- ✅ **FiveM puede LEER y ESCRIBIR** (el archivo real)
- ✅ **Sincronización**: FiveM → Web (unidireccional)

**Esto significa:**
- Los profesores editan desde el juego (FiveM) ✅
- Los usuarios ven desde la web ✅
- Los cambios desde FiveM se reflejan en la web ✅
- Los cambios desde la web NO persisten (solo cache) ⚠️

**Si necesitas editar desde web con persistencia**, lee `NOTA_VERCEL.md` para implementar una base de datos.

---

## 🔄 Paso 4: Actualizar Configuración de FiveM

Edita `config.lua` en tu servidor de FiveM:

```lua
Config.WebServer = {
    enabled = true,
    url = "https://tu-proyecto.vercel.app",  -- Tu URL de Vercel
    syncInterval = 30,
    apiKey = ""
}
```

Reinicia el recurso:
```bash
restart cat_calendario
```

**Nota:** La sincronización es principalmente FiveM → Web. Los cambios desde la web se guardan en cache pero no persisten hasta que FiveM los lea.

---

## 📝 Paso 5: Configurar Usuarios

### Opción A: Desde el Código (Recomendado)

Los usuarios se crean automáticamente con el usuario por defecto:
- **Usuario:** `admin`
- **Contraseña:** `admin123`

### Opción B: Crear Archivo users.json

1. Crea `web-server/users.json` en tu proyecto:

```json
[
  {
    "username": "admin",
    "password": "$2a$10$TU_HASH_AQUI",
    "permisos": ["editar"]
  }
]
```

2. Para generar el hash de contraseña, usa este código Node.js:

```javascript
const bcrypt = require('bcryptjs');
console.log(bcrypt.hashSync('tu_contraseña', 10));
```

3. Sube el cambio a GitHub:
```bash
git add web-server/users.json
git commit -m "Agregar usuarios"
git push
```

4. Vercel se actualizará automáticamente

---

## 🔄 Actualizaciones Futuras

Cada vez que hagas cambios:

```bash
# Hacer cambios en los archivos
# ...

# Agregar cambios
git add .

# Hacer commit
git commit -m "Descripción de los cambios"

# Subir a GitHub
git push
```

**Vercel se actualizará automáticamente** en 1-2 minutos.

---

## 🐛 Solución de Problemas

### Error: "Module not found"

**Solución:** Asegúrate de que `package.json` tenga todas las dependencias:
```bash
npm install
git add package.json package-lock.json
git commit -m "Actualizar dependencias"
git push
```

### Error: "Function timeout"

**Solución:** Vercel tiene un límite de 10 segundos en plan gratis. Si tu función tarda mucho, optimiza el código.

### El calendario no se actualiza

**Solución:** 
1. Verifica que `calendario_data.json` esté en el repositorio
2. Verifica que la URL en `config.lua` sea correcta
3. Revisa los logs en Vercel: Dashboard → Tu proyecto → Functions → Ver logs

### No puedo iniciar sesión

**Solución:**
1. Verifica que `JWT_SECRET` esté configurado en Vercel
2. Verifica que `users.json` exista
3. Revisa los logs de la función `/api/login`

---

## 📊 Monitoreo

### Ver Logs en Vercel

1. Ve a tu proyecto en Vercel
2. Haz clic en **"Functions"**
3. Selecciona una función
4. Verás los logs en tiempo real

### Ver Analytics

Vercel te da estadísticas básicas gratis:
- Visitas
- Tiempo de respuesta
- Errores

---

## 🔒 Seguridad

### Cambiar JWT_SECRET

1. Genera un nuevo secreto aleatorio
2. En Vercel: Settings → Environment Variables
3. Edita `JWT_SECRET` con el nuevo valor
4. Haz redeploy

### Cambiar Contraseñas

Edita `web-server/users.json` con nuevos hashes y sube a GitHub.

---

## ✅ Checklist Final

- [ ] Código subido a GitHub
- [ ] Proyecto importado en Vercel
- [ ] Variable `JWT_SECRET` configurada
- [ ] Deploy exitoso
- [ ] URL funcionando
- [ ] Login funcionando
- [ ] Configuración de FiveM actualizada
- [ ] Sincronización funcionando

---

## 🎉 ¡Listo!

Tu calendario ahora está disponible en internet y se sincroniza automáticamente con tu servidor de FiveM.

**URL pública:** `https://tu-proyecto.vercel.app/web`

**API:** `https://tu-proyecto.vercel.app/api/calendario`

