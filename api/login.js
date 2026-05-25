// Endpoint de login del calendario web.
//
// Antes este archivo leía web-server/users.json (read-only en Vercel) y sólo
// existía un único usuario "admin". Ahora los usuarios viven en la tabla
// MySQL `calendario_usuarios` y cada uno tiene un rol: 'admin' o 'profesor'.
//
// Bootstrap: si la tabla está vacía y se han configurado las variables de
// entorno BOOTSTRAP_ADMIN_USER + BOOTSTRAP_ADMIN_PASS, ese usuario puede
// iniciar sesión como admin. En ese momento se inserta también en la tabla,
// y a partir de ahí ya gana el valor almacenado en BD.

const bcrypt = require('bcryptjs');
const { obtenerConexion, asegurarTablas, registrarLog } = require('../lib/db');
const { firmarToken } = require('../lib/auth');

async function buscarUsuario(conexion, username) {
    const [rows] = await conexion.execute(
        'SELECT id, username, password_hash, rol FROM calendario_usuarios WHERE username = ? LIMIT 1',
        [username]
    );
    return rows && rows.length ? rows[0] : null;
}

async function contarUsuarios(conexion) {
    const [rows] = await conexion.execute('SELECT COUNT(*) AS n FROM calendario_usuarios');
    return rows && rows.length ? Number(rows[0].n) : 0;
}

async function intentarBootstrap(conexion, username, password) {
    const bootUser = (process.env.BOOTSTRAP_ADMIN_USER || '').trim();
    const bootPass = process.env.BOOTSTRAP_ADMIN_PASS || '';
    if (!bootUser || !bootPass) return null;

    if (username !== bootUser) return null;
    if (password !== bootPass) return null;

    const total = await contarUsuarios(conexion);
    if (total > 0) return null;

    const hash = await bcrypt.hash(password, 10);
    await conexion.execute(
        'INSERT INTO calendario_usuarios (username, password_hash, rol, creado_por) VALUES (?, ?, ?, ?)',
        [bootUser, hash, 'admin', 'bootstrap']
    );
    await registrarLog(conexion, {
        username: bootUser,
        rol: 'admin',
        accion: 'Bootstrap admin',
        detalles: 'Cuenta admin creada automáticamente desde BOOTSTRAP_ADMIN_USER/PASS.'
    });
    console.log('[Login] Bootstrap: creada cuenta admin "' + bootUser + '" desde variables de entorno.');
    return await buscarUsuario(conexion, bootUser);
}

module.exports = async function handler(req, res) {
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
        return res.status(200).end();
    }

    if (req.method !== 'POST') {
        return res.status(405).json({ error: 'Method not allowed' });
    }

    const { username, password } = req.body || {};
    if (!username || !password) {
        return res.status(400).json({ error: 'Usuario y contraseña requeridos' });
    }

    let conexion = null;
    try {
        conexion = await obtenerConexion();
        if (!conexion) {
            return res.status(500).json({ error: 'No se pudo conectar a la base de datos' });
        }
        await asegurarTablas(conexion);

        let usuario = await buscarUsuario(conexion, username);

        if (!usuario) {
            // No existe en BD -> intentar bootstrap (sólo crea la cuenta si la
            // tabla está vacía y las credenciales casan con BOOTSTRAP_*).
            usuario = await intentarBootstrap(conexion, username, password);
            if (!usuario) {
                return res.status(401).json({ error: 'Usuario o contraseña incorrectos' });
            }
            // Login exitoso por bootstrap (la contraseña ya se ha validado
            // contra BOOTSTRAP_ADMIN_PASS); seguimos al return.
            const token = firmarToken({
                username: usuario.username,
                rol: usuario.rol,
                permisos: ['editar']
            });
            return res.status(200).json({
                success: true,
                token,
                usuario: {
                    username: usuario.username,
                    rol: usuario.rol,
                    permisos: ['editar']
                }
            });
        }

        const passwordValido = await bcrypt.compare(password, usuario.password_hash);
        if (!passwordValido) {
            return res.status(401).json({ error: 'Usuario o contraseña incorrectos' });
        }

        const token = firmarToken({
            username: usuario.username,
            rol: usuario.rol,
            permisos: ['editar']
        });

        return res.status(200).json({
            success: true,
            token,
            usuario: {
                username: usuario.username,
                rol: usuario.rol,
                permisos: ['editar']
            }
        });
    } catch (error) {
        console.error('[Login] Error:', error);
        return res.status(500).json({ error: 'Error en el proceso de autenticación' });
    } finally {
        if (conexion) {
            try { await conexion.end(); } catch (_) {}
        }
    }
};
