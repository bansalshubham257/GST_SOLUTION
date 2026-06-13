// backend/src/routes/scan_bill.routes.js

const router = require('express').Router();
const multer = require('multer');
const { authenticate } = require('../middleware/auth');
const { scanBill } = require('../controllers/scan_bill.controller');

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB for bill images
  fileFilter: (req, file, cb) => {
    const allowed = ['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'application/pdf'];
    if (allowed.includes(file.mimetype)) cb(null, true);
    else cb(new Error('Only image files (JPEG, PNG, WEBP) and PDFs are accepted'), false);
  },
});

/**
 * POST /api/v1/invoices/scan-bill
 *
 * Scan an offline bill and extract structured data.
 *
 * Accepts two modes:
 *   1. JSON body with { text: "raw OCR text from client" }       ← preferred (Flutter ML Kit)
 *   2. Multipart form-data with image file (field: "bill")       ← requires server-side OCR
 *
 * Response:
 *   {
 *     success: true,
 *     data: {
 *       customerName, customerGstin, customerPhone, customerEmail, customerAddress,
 *       supplierName, supplierGstin, invoiceNumber, invoiceDate,
 *       lineItems: [{ description, quantity, unitPrice, gstRate, amount, hsnCode }],
 *       totalAmount, totalGst, subTotal, rawText, confidence
 *     }
 *   }
 */
router.post('/', authenticate, upload.single('bill'), scanBill);

module.exports = router;

