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

// ── Profil XLSX (reseed admin depuis un fichier, 20 Mo max) ──────────────────
// Stockage en mémoire (pas de persistance disque) : le fichier n'est utile
// qu'une fois, le temps du parsing par xlsx.
const XLSX_MIME = [
  'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'application/vnd.ms-excel',
];
const MAX_XLSX_MB = 20;

const xlsxUpload = multer({
  storage: multer.memoryStorage(),
  fileFilter: (_req, file, cb) => {
    if (XLSX_MIME.includes(file.mimetype) || file.originalname.toLowerCase().endsWith('.xlsx')) {
      return cb(null, true);
    }
    cb(new multer.MulterError('LIMIT_UNEXPECTED_FILE',
      `Type non supporté : ${file.mimetype}. Seul .xlsx est accepté.`));
  },
  limits: { fileSize: MAX_XLSX_MB * 1024 * 1024 },
});

module.exports = { documentUpload, photoUpload, xlsxUpload };
