// Helpers de autenticación compartidos por los handlers de /api.
// Vive en /lib/ para que Vercel no lo exponga como ruta HTTP.

const jwt = require('jsonwebtoken');

function getJwtSecret() {
    return process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';
}

// Decodifica el header Authorization: Bearer <token>.
// Devuelve el payload (con username, rol, permisos) o null si falta/invalida.
function verificarBearer(req) {
    try {
        const auth = req && req.headers && req.headers.authorization;
        if (!auth || !auth.startsWith('Bearer ')) return null;
        const token = auth.replace('Bearer ', '').trim();
        if (!token) return null;
        return jwt.verify(token, getJwtSecret());
    } catch (e) {
        return null;
    }
}

// Para handlers que sólo deben atender a admins (gestión de usuarios, logs).
// Si OK -> devuelve payload. Si no -> escribe 401/403 y devuelve null.
function exigirAdmin(req, res) {
    const payload = verificarBearer(req);
    if (!payload) {
        res.status(401).json({ error: 'Token no proporcionado o inválido' });
        return null;
    }
    if (payload.rol !== 'admin') {
        res.status(403).json({ error: 'Esta acción requiere rol de administrador' });
        return null;
    }
    return payload;
}

// Firma un JWT estándar para el calendario.
function firmarToken(usuario) {
    return jwt.sign(
        {
            username: usuario.username,
            rol: usuario.rol || 'profesor',
            permisos: usuario.permisos || ['editar'],
            id: usuario.id || usuario.username
        },
        getJwtSecret(),
        { expiresIn: '24h' }
    );
}

function permisosParaRol(rol) {
    if (rol === 'admin') {
        return ['editar', 'publicar'];
    }

    return ['editar'];
}

function normalizarPermisos(payload) {
    if (!payload || typeof payload !== 'object') {
        return [];
    }

    if (Array.isArray(payload.permisos) && payload.permisos.length > 0) {
        return payload.permisos;
    }

    return permisosParaRol(payload.rol || 'profesor');
}

module.exports = { getJwtSecret, verificarBearer, exigirAdmin, firmarToken, permisosParaRol, normalizarPermisos };
