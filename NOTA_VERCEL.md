# ⚠️ Nota Importante sobre Vercel

## Limitación de Vercel

**Vercel usa funciones serverless** que tienen un sistema de archivos de **solo lectura**. Esto significa que:

- ✅ **Puedes LEER** archivos del repositorio (como `calendario_data.json`)
- ❌ **NO puedes ESCRIBIR** archivos de forma persistente

## Soluciones

### Opción 1: Usar Base de Datos (Recomendado para Producción)

Usa una base de datos gratuita como:
- **MongoDB Atlas** (gratis hasta 512MB)
- **Supabase** (PostgreSQL gratis)
- **PlanetScale** (MySQL gratis)

### Opción 2: Usar Almacenamiento en la Nube

- **AWS S3** (con IAM)
- **Cloudinary** (para JSON)
- **Vercel Blob Storage** (nuevo servicio de Vercel)

### Opción 3: Sincronización con FiveM (Actual)

El sistema actual funciona así:
1. **Lectura desde web**: Lee el archivo `calendario_data.json` del repositorio
2. **Escritura desde web**: Actualiza el cache en memoria (temporal)
3. **Persistencia real**: El servidor de FiveM lee/escribe el archivo real
4. **Sincronización**: FiveM sincroniza cambios cada X segundos

**Esto funciona porque:**
- El archivo `calendario_data.json` está en el repositorio
- FiveM puede leer/escribir el archivo localmente
- La web solo lee (y actualiza cache temporal)
- Los cambios reales vienen de FiveM

### Opción 4: Webhook de GitHub (Avanzado)

Puedes crear un webhook que:
1. Recibe cambios desde la web
2. Actualiza el archivo en GitHub mediante API
3. Vercel se actualiza automáticamente

---

## Implementación Actual

El código actual funciona así:

1. **Web lee**: Lee `calendario_data.json` del repositorio
2. **Web escribe**: Actualiza cache en memoria (no persiste)
3. **FiveM escribe**: Escribe el archivo real en el servidor
4. **Sincronización**: FiveM verifica cambios periódicamente

**Esto significa:**
- ✅ Los cambios desde FiveM se reflejan en la web
- ⚠️ Los cambios desde la web NO persisten (solo en cache)
- ✅ Para persistir desde web, necesitas una de las opciones arriba

---

## Recomendación

Para empezar, el sistema actual funciona bien porque:
- Los profesores editan desde el juego (FiveM)
- Los usuarios ven desde la web
- La sincronización es unidireccional (FiveM → Web)

Si necesitas que los usuarios editen desde la web y persista, implementa una base de datos.

---

## Cómo Implementar Base de Datos (MongoDB Atlas - Gratis)

### 1. Crear cuenta en MongoDB Atlas
https://www.mongodb.com/cloud/atlas

### 2. Crear cluster gratuito

### 3. Obtener connection string

### 4. Instalar dependencia
```bash
npm install mongodb
```

### 5. Modificar `api/calendario.js`

```javascript
const { MongoClient } = require('mongodb');

const client = new MongoClient(process.env.MONGODB_URI);

async function leerCalendario() {
    try {
        await client.connect();
        const db = client.db('calendario');
        const collection = db.collection('datos');
        const doc = await collection.findOne({ _id: 'calendario' });
        return doc ? doc.data : null;
    } catch (error) {
        console.error('Error:', error);
        return null;
    }
}

async function guardarCalendario(datos) {
    try {
        await client.connect();
        const db = client.db('calendario');
        const collection = db.collection('datos');
        await collection.updateOne(
            { _id: 'calendario' },
            { $set: { data: datos, updated: new Date() } },
            { upsert: true }
        );
        return true;
    } catch (error) {
        console.error('Error:', error);
        return false;
    }
}
```

### 6. Agregar variable de entorno en Vercel
- Name: `MONGODB_URI`
- Value: `mongodb+srv://usuario:password@cluster.mongodb.net/calendario`

---

## Conclusión

El sistema actual funciona para **lectura desde web** y **edición desde FiveM**.

Si necesitas **edición desde web con persistencia**, implementa una base de datos.

