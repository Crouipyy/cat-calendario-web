const jwt = require('jsonwebtoken');

export default async function handler(req, res) {
    // Configurar CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method === 'GET') {
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith('Bearer ')) {
            return res.status(401).json({
                error: 'Token no proporcionado'
            });
        }

        const token = authHeader.replace('Bearer ', '');

        try {
            const JWT_SECRET = process.env.JWT_SECRET || 'tu_secreto_super_seguro_cambiar_en_produccion';
            const decoded = jwt.verify(token, JWT_SECRET);

            return res.status(200).json({
                success: true,
                usuario: {
                    username: decoded.username,
                    permisos: decoded.permisos || []
                }
            });
        } catch (error) {
            return res.status(401).json({
                error: 'Token inválido'
            });
        }
    }

    return res.status(405).json({
        error: 'Method not allowed'
    });
}

