# 📝 Resumen Rápido: Deploy en Vercel

## ✅ Archivos Creados/Modificados

He adaptado tu proyecto para Vercel. Estos son los archivos nuevos:

### Nuevos Archivos:
- ✅ `api/calendario.js` - API para leer/guardar calendario
- ✅ `api/login.js` - API para autenticación
- ✅ `api/verificar.js` - API para verificar token
- ✅ `api/config.js` - API para configuración
- ✅ `vercel.json` - Configuración de Vercel
- ✅ `package.json` - Dependencias (raíz del proyecto)
- ✅ `.gitignore` - Archivos a ignorar en Git
- ✅ `GUIA_VERCEL.md` - Guía completa paso a paso

### Archivos Modificados:
- ✅ `nui/index.html` - Agregado detección automática de modo web

---

## 🚀 Pasos Rápidos

### 1. Inicializar Git (si no lo has hecho)
```bash
git init
git add .
git commit -m "Preparado para Vercel"
```

### 2. Crear Repositorio en GitHub
1. Ve a https://github.com
2. Clic en "New repository"
3. Nombre: `cat-calendario-web`
4. Clic en "Create repository"

### 3. Subir a GitHub
```bash
git remote add origin https://github.com/TU_USUARIO/cat-calendario-web.git
git branch -M main
git push -u origin main
```

### 4. Deploy en Vercel
1. Ve a https://vercel.com
2. "Add New Project"
3. Importa tu repositorio de GitHub
4. **Agrega variable de entorno:**
   - Name: `JWT_SECRET`
   - Value: `tu_secreto_super_seguro_123456` (cambia esto)
5. Clic en "Deploy"

### 5. ¡Listo!
Tu URL será: `https://tu-proyecto.vercel.app/web`

---

## ⚙️ Configuración de FiveM

Actualiza `config.lua`:

```lua
Config.WebServer = {
    enabled = true,
    url = "https://tu-proyecto.vercel.app",  -- Tu URL de Vercel
    syncInterval = 30
}
```

---

## 🔑 Credenciales por Defecto

- **Usuario:** `admin`
- **Contraseña:** `admin123`

⚠️ **Cambia estas credenciales en producción**

---

## 📚 Documentación Completa

Lee `GUIA_VERCEL.md` para la guía completa con todos los detalles.

---

## 🐛 Problemas Comunes

### "Module not found"
→ Ejecuta `npm install` y sube `package-lock.json`

### "Function timeout"
→ Vercel tiene límite de 10 segundos. Optimiza el código.

### No puedo iniciar sesión
→ Verifica que `JWT_SECRET` esté configurado en Vercel

---

## ✅ Checklist

- [ ] Código subido a GitHub
- [ ] Proyecto importado en Vercel
- [ ] Variable `JWT_SECRET` configurada
- [ ] Deploy exitoso
- [ ] URL funcionando
- [ ] Configuración de FiveM actualizada

