// backend/src/routes/gst.routes.js
const router = require('express').Router();
const { authenticate, requireBusiness } = require('../middleware/auth');
const {
  getGstSummary, getSalesRegister, getGstr1Draft, getGstr3bDraft,
  getTaxLiability, validateGstinEndpoint, getFilingChecklist,
  generateFilingJson, exportReport,
} = require('../controllers/gst.controller');

router.use(authenticate);
router.post('/validate', validateGstinEndpoint);

router.use(requireBusiness);
router.get('/summary', getGstSummary);
router.get('/sales-register', getSalesRegister);
router.get('/tax-liability', getTaxLiability);
router.get('/gstr1-draft', getGstr1Draft);
router.get('/gstr3b-draft', getGstr3bDraft);
router.get('/filing-checklist', getFilingChecklist);
router.get('/generate-json', generateFilingJson);
router.get('/export', exportReport);

module.exports = router;

