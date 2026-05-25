// CRUD de usuarios del calendario. Sólo accesible para administradores.
//
//  GET    /api/usuarios                -> lista (id, username, rol, fechas)
//  POST   /api/usuarios                -> crea usuario { username, password, rol }
//  PUT    /api/usuarios?username=xxx   -> actualiza { password?, rol? }
//  DELETE /api/usuarios?username=xxx   -> elimina (no se puede borrar a sí mismo
//                                         ni vaciar el último admin)

const bcrypt = require('bcryptjs');
const { obtenerConexion, asegurarTablas, registrarLog } = require('../lib/db');
const { exigirAdmin } = require('../lib/auth');

const ROLES_VALIDOS = new Set(['admin', 'profesor']);
const USERNAME_REGEX = /^[a-zA-Z0-9._-]{3,64}$/;

async function listarUsuarios(conexion) {
    const [rows] = await conexion.execute(
        'SELECT id, username, rol, creado_por, creado_en, actualizado_en FROM calendario_usuarios ORDER BY rol DESC, username ASC'
    );
    return rows || [];
}

async function contarAdmins(conexion) {
    const [rows] = await conexion.execute(
        "SELECT COUNT(*) AS n FROM calendario_usuarios WHERE rol = 'admin'"
    );
    return rows && rows.length ? Number(rows[0].n) : 0;
}

module.exports = async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    const adminPayload = exigirAdmin(req, res);
    if (!adminPayload) return; // exigirAdmin ya respondió

    let conexion = null;
    try {
        conexion = await obtenerConexion();
        if (!conexion) {
            return res.status(500).json({ error: 'No se pudo conectar a la base de datos' });
        }
        await asegurarTablas(conexion);

        if (req.method === 'GET') {
            const usuarios = await listarUsuarios(conexion);
            return res.status(200).json({ success: true, usuarios });
        }

        if (req.method === 'POST') {
            const { username, password, rol } = req.body || {};
            if (!username || !password || !rol) {
                return res.status(400).json({ error: 'username, password y rol son obligatorios' });
            }
            if (!USERNAME_REGEX.test(username)) {
                return res.status(400).json({ error: 'username debe tener 3-64 caracteres (letras, números, . _ -)' });
            }
            if (typeof password !== 'string' || password.length < 6) {
                return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
            }
            if (!ROLES_VALIDOS.has(rol)) {
                return res.status(400).json({ error: 'rol inválido (admin|profesor)' });
            }

            const [existing] = await conexion.execute(
                'SELECT id FROM calendario_usuarios WHERE username = ? LIMIT 1',
                [username]
            );
            if (existing && existing.length) {
                return res.status(409).json({ error: 'Ya existe un usuario con ese nombre' });
            }

            const hash = await bcrypt.hash(password, 10);
            await conexion.execute(
                'INSERT INTO calendario_usuarios (username, password_hash, rol, creado_por) VALUES (?, ?, ?, ?)',
                [username, hash, rol, adminPayload.username]
            );
            await registrarLog(conexion, {
                username: adminPayload.username,
                rol: adminPayload.rol,
                accion: 'Crear usuario',
                detalles: 'Nuevo usuario "' + username + '" con rol ' + rol
            });

            return res.status(201).json({
                success: true,
                usuario: { username, rol, creado_por: adminPayload.username }
            });
        }

        if (req.method === 'PUT') {
            const username = (req.query && req.query.username) || (req.body && req.body.username);
            if (!username) {
                return res.status(400).json({ error: 'Falta username' });
            }

            const [rows] = await conexion.execute(
                'SELECT id, username, rol FROM calendario_usuarios WHERE username = ? LIMIT 1',
                [username]
            );
            if (!rows || !rows.length) {
                return res.status(404).json({ error: 'Usuario no encontrado' });
            }
            const objetivo = rows[0];

            const cambios = [];
            const params = [];
            const detalles = [];

            const nuevaPass = req.body && req.body.password;
            if (nuevaPass) {
                if (typeof nuevaPass !== 'string' || nuevaPass.length < 6) {
                    return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres' });
                }
                const hash = await bcrypt.hash(nuevaPass, 10);
                cambios.push('password_hash = ?');
                params.push(hash);
                detalles.push('contraseña');
            }

            const nuevoRol = req.body && req.body.rol;
            if (nuevoRol) {
                if (!ROLES_VALIDOS.has(nuevoRol)) {
                    return res.status(400).json({ error: 'rol inválido' });
                }
                if (objetivo.rol === 'admin' && nuevoRol !== 'admin') {
                    const totalAdmins = await contarAdmins(conexion);
                    if (totalAdmins <= 1) {
                        return res.status(409).json({ error: 'No puedes degradar al último administrador' });
                    }
                }
                cambios.push('rol = ?');
                params.push(nuevoRol);
                detalles.push('rol -> ' + nuevoRol);
            }

            if (!cambios.length) {
                return res.status(400).json({ error: 'Nada que actualizar (envía password y/o rol)' });
            }

            params.push(objetivo.id);
            await conexion.execute(
                'UPDATE calendario_usuarios SET ' + cambios.join(', ') + ' WHERE id = ?',
                params
            );
            await registrarLog(conexion, {
                username: adminPayload.username,
                rol: adminPayload.rol,
                accion: 'Actualizar usuario',
                detalles: 'Modificado "' + username + '": ' + detalles.join(', ')
            });

            return res.status(200).json({ success: true });
        }

        if (req.method === 'DELETE') {
            const username = (req.query && req.query.username) || (req.body && req.body.username);
            if (!username) {
                return res.status(400).json({ error: 'Falta username' });
            }
            if (username === adminPayload.username) {
                return res.status(409).json({ error: 'No puedes eliminar tu propia cuenta mientras estás conectado' });
            }

            const [rows] = await conexion.execute(
                'SELECT id, username, rol FROM calendario_usuarios WHERE username = ? LIMIT 1',
                [username]
            );
            if (!rows || !rows.length) {
                return res.status(404).json({ error: 'Usuario no encontrado' });
            }
            const objetivo = rows[0];

            if (objetivo.rol === 'admin') {
                const totalAdmins = await contarAdmins(conexion);
                if (totalAdmins <= 1) {
                    return res.status(409).json({ error: 'No puedes eliminar al único administrador' });
                }
            }

            await conexion.execute('DELETE FROM calendario_usuarios WHERE id = ?', [objetivo.id]);
            await registrarLog(conexion, {
                username: adminPayload.username,
                rol: adminPayload.rol,
                accion: 'Eliminar usuario',
                detalles: 'Eliminado "' + username + '" (rol ' + objetivo.rol + ')'
            });

            return res.status(200).json({ success: true });
        }

        return res.status(405).json({ error: 'Method not allowed' });
    } catch (error) {
        console.error('[api/usuarios] Error:', error);
        return res.status(500).json({ error: 'Error interno' });
    } finally {
        if (conexion) {
            try { await conexion.end(); } catch (_) {}
        }
    }
};
