const multer = require('multer');
const path   = require('path');
const crypto = require('crypto');
const { UPLOAD_DIR } = require('../config');

const ALLOWED_MIME  = ['image/jpeg', 'image/png', 'application/pdf'];
const PHOTO_MIME    = ['image/jpeg', 'image/png'];
const MAX_DOC_MB    = 10;
const MAX_PHOTO_MB  = 5;

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, UPLOAD_DIR),
  filename:    (_req, file, cb) => {
    const ext = path.extname(file.originalname).toLowerCase() || '.bin';
    cb(null, crypto.randomUUID() + ext);
  },
});

// ── Profil documents (PDF + images, 10 Mo) ────────────────────────────────────
const documentUpload = multer({
  storage,
  fileFilter: (_req, file, cb) => {
    if (ALLOWED_MIME.includes(file.mimetype)) return cb(null, true);
    cb(new multer.MulterError('LIMIT_UNEXPECTED_FILE',
      `Type non supporté : ${file.mimetype}. Acceptés : ${ALLOWED_MIME.join(', ')}`));
  },
  limits: { fileSize: MAX_DOC_MB * 1024 * 1024 },
});

// ── Profil photos incidents (JPEG/PNG uniquement, 5 Mo max, 5 fichiers) ───────
const photoUpload = multer({
  storage,
  fileFilter: (_req, file, cb) => {
    if (PHOTO_MIME.includes(file.mimetype)) return cb(null, true);
    cb(new multer.MulterError('LIMIT_UNEXPECTED_FILE',
      `Type non supporté : ${file.mimetype}. Seuls JPEG et PNG sont acceptés.`));
  },
  limits: { fileSize: MAX_PHOTO_MB * 1024 * 1024, files: 5 },
});

module.exports = { documentUpload, photoUpload };
