# 🔧 Solución: Problemas con Git y GitHub

## Problema Actual

Estás usando `TU_USUARIO` literalmente en lugar de tu usuario real de GitHub.

## Solución Paso a Paso

### Paso 1: Verificar tu Remote Actual

```bash
git remote -v
```

Esto te mostrará qué remote tienes configurado.

### Paso 2: Eliminar el Remote Incorrecto

```bash
git remote remove origin
```

### Paso 3: Verificar tu Usuario de GitHub

1. Ve a https://github.com
2. Haz clic en tu foto de perfil (arriba derecha)
3. Tu usuario está en la URL o en tu perfil

**Ejemplo:** Si tu URL es `https://github.com/jorge123`, tu usuario es `jorge123`

### Paso 4: Crear el Repositorio en GitHub (si no lo has hecho)

1. Ve a https://github.com/new
2. Nombre del repositorio: `cat-calendario-web`
3. **NO marques** "Initialize with README"
4. Haz clic en **"Create repository"**

### Paso 5: Agregar el Remote Correcto

**Reemplaza `TU_USUARIO_REAL` con tu usuario real de GitHub:**

```bash
git remote add origin https://github.com/TU_USUARIO_REAL/cat-calendario-web.git
```

**Ejemplo:**
```bash
git remote add origin https://github.com/jorge123/cat-calendario-web.git
```

### Paso 6: Verificar que estás en la rama main

```bash
git branch
```

Si estás en `master`, cambia a `main`:
```bash
git branch -M main
```

### Paso 7: Hacer Push

```bash
git push -u origin main
```

**Si te pide autenticación:**

#### Opción A: Personal Access Token (Recomendado)

1. Ve a: https://github.com/settings/tokens
2. Clic en **"Generate new token"** → **"Generate new token (classic)"**
3. Nombre: `Vercel Deploy`
4. Expiración: `90 days` (o la que prefieras)
5. Permisos: Marca `repo` (acceso completo a repositorios)
6. Clic en **"Generate token"**
7. **COPIA EL TOKEN** (solo se muestra una vez)
8. Cuando Git te pida contraseña, usa el **token** (no tu contraseña de GitHub)

#### Opción B: GitHub CLI

```bash
# Instalar GitHub CLI si no lo tienes
# Luego:
gh auth login
```

---

## Comandos Completos (Copia y Pega)

**Reemplaza `TU_USUARIO_REAL` con tu usuario:**

```bash
# 1. Eliminar remote incorrecto
git remote remove origin

# 2. Verificar rama
git branch

# 3. Si estás en master, cambiar a main
git branch -M main

# 4. Agregar remote correcto (REEMPLAZA TU_USUARIO_REAL)
git remote add origin https://github.com/TU_USUARIO_REAL/cat-calendario-web.git

# 5. Verificar remote
git remote -v

# 6. Hacer push
git push -u origin main
```

---

## Si el Repositorio No Existe

Si GitHub dice "Repository not found", necesitas crearlo primero:

1. Ve a https://github.com/new
2. Nombre: `cat-calendario-web`
3. **NO marques** "Initialize with README"
4. Clic en **"Create repository"**
5. Luego ejecuta los comandos de arriba

---

## Verificar que Funcionó

Después del push, deberías ver algo como:

```
Enumerating objects: 28, done.
Counting objects: 100% (28/28), done.
Writing objects: 100% (28/28), done.
To https://github.com/TU_USUARIO/cat-calendario-web.git
 * [new branch]      main -> main
Branch 'main' set up to track remote branch 'main' from 'origin'.
```

Luego ve a: `https://github.com/TU_USUARIO/cat-calendario-web` y deberías ver todos tus archivos.

