// Verifica que el JWT que el cliente guarda en localStorage sigue siendo
// válido. Devuelve también el rol para que la UI sepa si tiene que pintar
// el panel de Administración.

const { verificarBearer, normalizarPermisos } = require('../lib/auth');

module.exports = async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'GET') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const payload = verificarBearer(req);
    if (!payload) {
        return res.status(401).json({ error: 'Token no proporcionado o inválido' });
    }

    const permisos = normalizarPermisos(payload);

    return res.status(200).json({
        success: true,
        usuario: {
            username: payload.username,
            rol: payload.rol || 'profesor',
            permisos: permisos
        }
    });
};
