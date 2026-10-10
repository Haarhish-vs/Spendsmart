const express = require('express');
const aiPlanController = require('../controllers/ai-plan.controller');
const aiPlanValidator = require('../validators/ai-plan.validator');

const router = express.Router();

router.get('/', aiPlanController.getPlan);
router.post('/generate', aiPlanValidator.validateGeneratePlan, aiPlanController.generatePlan);

module.exports = router;
