export default async function handler(req, res) {
    // Configurar CORS
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method === 'GET') {
        // Retornar información básica
        // La configuración completa está en el cliente
        return res.status(200).json({
            success: true,
            message: 'Configuración disponible en el cliente'
        });
    }

    return res.status(405).json({
        error: 'Method not allowed'
    });
}

