// backend/src/routes/upload.routes.js
const router = require('express').Router();
const multer = require('multer');
const { authenticate } = require('../middleware/auth');
const { uploadFile } = require('../services/storageService');
const { AppError } = require('../middleware/errorHandler');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 }, // 5MB
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/svg+xml'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new AppError('Only image files are allowed', 400, 'INVALID_FILE_TYPE'));
  },
});

/**
 * POST /upload/logo
 */
router.post('/logo', authenticate, upload.single('logo'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

    const fileName = `logos/${req.user.id}_${Date.now()}.${req.file.mimetype.split('/')[1]}`;
    const result = await uploadFile({
      buffer: req.file.buffer,
      fileName,
      mimeType: req.file.mimetype,
    });

    res.json({ url: result.url, message: 'Logo uploaded successfully' });
  } catch (err) {
    next(err);
  }
});

/**
 * POST /upload/signature
 */
router.post('/signature', authenticate, upload.single('signature'), async (req, res, next) => {
  try {
    if (!req.file) return res.status(400).json({ error: 'No file uploaded' });

    const fileName = `signatures/${req.user.id}_${Date.now()}.png`;
    const result = await uploadFile({
      buffer: req.file.buffer,
      fileName,
      mimeType: req.file.mimetype,
    });

    res.json({ url: result.url });
  } catch (err) {
    next(err);
  }
});

module.exports = router;

