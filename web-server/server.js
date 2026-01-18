const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const fs = require('fs-extra');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;
const JWT_SECRET = process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';

// Configuración
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Servir archivos estáticos (HTML, CSS, JS, imágenes)
const staticPath = path.join(__dirname, '../nui');
app.use('/static', express.static(staticPath));

// Ruta para servir el HTML principal
app.get('/', (req, res) => {
    const htmlPath = path.join(__dirname, '../nui/index.html');
    if (fs.existsSync(htmlPath)) {
        res.sendFile(htmlPath);
    } else {
        res.status(404).send('Archivo no encontrado');
    }
});

// Ruta para servir el HTML con modo web
app.get('/web', (req, res) => {
    const htmlPath = path.join(__dirname, '../nui/index.html');
    if (fs.existsSync(htmlPath)) {
        let html = fs.readFileSync(htmlPath, 'utf8');
        // Inyectar script para modo web
        html = html.replace('</body>', `
            <script>
                window.MODO_WEB = true;
                window.API_URL = 'http://${req.get('host')}';
            </script>
        </body>`);
        res.send(html);
    } else {
        res.status(404).send('Archivo no encontrado');
    }
});

// Ruta del archivo de datos del calendario
const dataPath = path.join(__dirname, '../calendario_data.json');

// Middleware para verificar token JWT
const verificarToken = (req, res, next) => {
    const token = req.headers['authorization']?.replace('Bearer ', '');
    
    if (!token) {
        return res.status(401).json({ error: 'Token no proporcionado' });
    }
    
    try {
        const decoded = jwt.verify(token, JWT_SECRET);
        req.usuario = decoded;
        next();
    } catch (error) {
        res.status(401).json({ error: 'Token inválido' });
    }
};

// GET: Obtener calendario (público para lectura)
app.get('/api/calendario', async (req, res) => {
    try {
        if (fs.existsSync(dataPath)) {
            const data = await fs.readJson(dataPath);
            res.json({ success: true, calendario: data });
        } else {
            res.json({ success: true, calendario: null });
        }
    } catch (error) {
        console.error('Error leyendo calendario:', error);
        res.status(500).json({ error: 'Error al leer el calendario' });
    }
});

// GET: Obtener configuración (público)
app.get('/api/config', async (req, res) => {
    try {
        // Leer config.lua y parsear (simplificado)
        const configPath = path.join(__dirname, '../config.lua');
        if (fs.existsSync(configPath)) {
            const configContent = fs.readFileSync(configPath, 'utf8');
            // Enviar un objeto básico - el cliente puede parsear config.lua si es necesario
            res.json({ 
                success: true, 
                message: 'Configuración disponible en el cliente',
                // Puedes agregar más datos parseados aquí si es necesario
            });
        } else {
            res.json({ success: true, config: null });
        }
    } catch (error) {
        console.error('Error leyendo config:', error);
        res.status(500).json({ error: 'Error al leer la configuración' });
    }
});

// POST: Guardar calendario (requiere autenticación)
app.post('/api/calendario', verificarToken, async (req, res) => {
    try {
        const { calendario } = req.body;
        
        if (!calendario) {
            return res.status(400).json({ error: 'Datos del calendario no proporcionados' });
        }
        
        // Guardar en archivo
        await fs.writeJson(dataPath, calendario, { spaces: 2 });
        
        // Actualizar timestamp
        calendario.ultimaActualizacion = Math.floor(Date.now() / 1000);
        
        console.log(`[API] Calendario actualizado por usuario: ${req.usuario.username}`);
        
        res.json({ 
            success: true, 
            message: 'Calendario guardado correctamente',
            ultimaActualizacion: calendario.ultimaActualizacion
        });
    } catch (error) {
        console.error('Error guardando calendario:', error);
        res.status(500).json({ error: 'Error al guardar el calendario' });
    }
});

// POST: Login para obtener token
app.post('/api/login', async (req, res) => {
    try {
        const { username, password } = req.body;
        
        // Verificar credenciales (en producción, usar base de datos)
        // Por ahora, usar usuarios del archivo users.json
        const usersPath = path.join(__dirname, 'users.json');
        let users = [];
        
        if (fs.existsSync(usersPath)) {
            users = await fs.readJson(usersPath);
        } else {
            // Crear usuario por defecto
            const defaultPassword = await bcrypt.hash('admin123', 10);
            users = [{
                username: 'admin',
                password: defaultPassword,
                permisos: ['editar']
            }];
            await fs.writeJson(usersPath, users, { spaces: 2 });
        }
        
        const usuario = users.find(u => u.username === username);
        
        if (!usuario) {
            return res.status(401).json({ error: 'Usuario o contraseña incorrectos' });
        }
        
        const passwordValido = await bcrypt.compare(password, usuario.password);
        
        if (!passwordValido) {
            return res.status(401).json({ error: 'Usuario o contraseña incorrectos' });
        }
        
        // Generar token
        const token = jwt.sign(
            { 
                username: usuario.username, 
                permisos: usuario.permisos || [],
                id: usuario.id || usuario.username
            },
            JWT_SECRET,
            { expiresIn: '24h' }
        );
        
        res.json({ 
            success: true, 
            token,
            usuario: {
                username: usuario.username,
                permisos: usuario.permisos || []
            }
        });
    } catch (error) {
        console.error('Error en login:', error);
        res.status(500).json({ error: 'Error en el proceso de autenticación' });
    }
});

// GET: Verificar token
app.get('/api/verificar', verificarToken, (req, res) => {
    res.json({ 
        success: true, 
        usuario: {
            username: req.usuario.username,
            permisos: req.usuario.permisos || []
        }
    });
});

// Iniciar servidor
app.listen(PORT, () => {
    console.log(`🚀 Servidor web del calendario iniciado en http://localhost:${PORT}`);
    console.log(`📅 Calendario público: http://localhost:${PORT}/web`);
    console.log(`🔐 API disponible en: http://localhost:${PORT}/api`);
});

