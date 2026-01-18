const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const fs = require('fs');
const path = require('path');

function leerUsuarios() {
    try {
        // Intentar leer desde el archivo del repositorio
        const usersPath = path.join(process.cwd(), 'web-server', 'users.json');
        
        if (fs.existsSync(usersPath)) {
            const contenido = fs.readFileSync(usersPath, 'utf8');
            const usuarios = JSON.parse(contenido);
            console.log('[Login] Usuarios cargados desde archivo');
            return usuarios;
        }
        
        // Si no existe el archivo, usar usuario por defecto hardcodeado
        // NOTA: En Vercel NO se puede escribir archivos (solo lectura)
        // Usamos un hash pre-generado de 'admin123'
        // Hash generado con: bcrypt.hashSync('admin123', 10)
        const defaultPasswordHash = '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy';
        
        const usuarios = [{
            username: 'admin',
            password: defaultPasswordHash,
            permisos: ['editar']
        }];
        
        console.log('[Login] Usando usuario por defecto (admin/admin123) - archivo no encontrado');
        return usuarios;
    } catch (error) {
        console.error('Error leyendo usuarios:', error);
        
        // Fallback: usuario por defecto hardcodeado con hash pre-generado
        // Hash de 'admin123' generado con bcrypt
        const defaultPasswordHash = '$2a$10$N9qo8uLOickgx2ZMRZoMyeIjZAgcfl7p92ldGxad68LJZdL17lhWy';
        console.log('[Login] Usando usuario por defecto (fallback)');
        return [{
            username: 'admin',
            password: defaultPasswordHash,
            permisos: ['editar']
        }];
    }
}

export default async function handler(req, res) {
    // Configurar CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method === 'POST') {
        try {
            const { username, password } = req.body;

            if (!username || !password) {
                return res.status(400).json({
                    error: 'Usuario y contraseña requeridos'
                });
            }

            const users = leerUsuarios();
            const usuario = users.find(u => u.username === username);

            if (!usuario) {
                return res.status(401).json({
                    error: 'Usuario o contraseña incorrectos'
                });
            }

            const passwordValido = await bcrypt.compare(password, usuario.password);

            if (!passwordValido) {
                return res.status(401).json({
                    error: 'Usuario o contraseña incorrectos'
                });
            }

            // Generar token
            const JWT_SECRET = process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';
            const token = jwt.sign(
                {
                    username: usuario.username,
                    permisos: usuario.permisos || [],
                    id: usuario.id || usuario.username
                },
                JWT_SECRET,
                { expiresIn: '24h' }
            );

            return res.status(200).json({
                success: true,
                token,
                usuario: {
                    username: usuario.username,
                    permisos: usuario.permisos || []
                }
            });
        } catch (error) {
            console.error('Error en login:', error);
            return res.status(500).json({
                error: 'Error en el proceso de autenticación'
            });
        }
    }

    return res.status(405).json({
        error: 'Method not allowed'
    });
}

