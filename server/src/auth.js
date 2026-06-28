'use strict';

// Single shared token auth. Set a strong AUTH_TOKEN in the environment.
const TOKEN = process.env.AUTH_TOKEN || '';

function checkToken(token) {
  return Boolean(TOKEN) && token === TOKEN;
}

// Express middleware: requires `Authorization: Bearer <token>` or `?token=`.
function authMiddleware(req, res, next) {
  if (!TOKEN) {
    return res
        .status(500)
        .json({ error: 'Server misconfigured: AUTH_TOKEN is not set.' });
  }
  const header = req.headers['authorization'] || '';
  const token = header.startsWith('Bearer ')
      ? header.slice(7)
      : (req.query.token || '');
  if (!checkToken(token)) {
    return res.status(401).json({ error: 'Unauthorized' });
  }
  next();
}

module.exports = { checkToken, authMiddleware };
