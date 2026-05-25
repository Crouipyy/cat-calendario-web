// Devuelve el historial de cambios del calendario y de la gestión de
// cuentas. Sólo accesible para administradores.
//
//   GET /api/logs?limit=100[&offset=0][&q=palabra][&desde=YYYY-MM-DD][&hasta=YYYY-MM-DD]

const { obtenerConexion, asegurarTablas } = require('../lib/db');
const { exigirAdmin } = require('../lib/auth');

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

    if (!exigirAdmin(req, res)) return;

    let conexion = null;
    try {
        conexion = await obtenerConexion();
        if (!conexion) {
            return res.status(500).json({ error: 'No se pudo conectar a la base de datos' });
        }
        await asegurarTablas(conexion);

        const q = (req.query && req.query.q) ? String(req.query.q).slice(0, 64) : '';
        const desde = (req.query && req.query.desde) ? String(req.query.desde).slice(0, 32) : '';
        const hasta = (req.query && req.query.hasta) ? String(req.query.hasta).slice(0, 32) : '';

        let limit = parseInt((req.query && req.query.limit) || '100', 10);
        if (!Number.isFinite(limit) || limit <= 0) limit = 100;
        if (limit > 500) limit = 500;

        let offset = parseInt((req.query && req.query.offset) || '0', 10);
        if (!Number.isFinite(offset) || offset < 0) offset = 0;

        const where = [];
        const params = [];
        if (q) {
            where.push('(username LIKE ? OR accion LIKE ? OR detalles LIKE ?)');
            const like = '%' + q + '%';
            params.push(like, like, like);
        }
        if (desde) {
            where.push('fecha >= ?');
            params.push(desde + ' 00:00:00');
        }
        if (hasta) {
            where.push('fecha <= ?');
            params.push(hasta + ' 23:59:59');
        }

        const whereSQL = where.length ? ('WHERE ' + where.join(' AND ')) : '';

        const [rows] = await conexion.execute(
            'SELECT id, fecha, username, rol, accion, detalles FROM calendario_logs ' +
            whereSQL + ' ORDER BY fecha DESC, id DESC LIMIT ' + limit + ' OFFSET ' + offset,
            params
        );
        const [countRows] = await conexion.execute(
            'SELECT COUNT(*) AS total FROM calendario_logs ' + whereSQL,
            params
        );
        const total = countRows && countRows.length ? Number(countRows[0].total) : 0;

        return res.status(200).json({
            success: true,
            total,
            limit,
            offset,
            logs: rows || []
        });
    } catch (error) {
        console.error('[api/logs] Error:', error);
        return res.status(500).json({ error: 'Error interno' });
    } finally {
        if (conexion) {
            try { await conexion.end(); } catch (_) {}
        }
    }
};
