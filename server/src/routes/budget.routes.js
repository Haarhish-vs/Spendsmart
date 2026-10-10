const express = require('express');
const budgetController = require('../controllers/budget.controller');

const router = express.Router();

router.get('/alerts/:userId', budgetController.getAlerts);
router.get('/:userId', budgetController.getAll);
router.get('/', budgetController.getAll);
router.post('/', budgetController.create);
router.put('/:id', budgetController.update);
router.delete('/:id', budgetController.delete);

module.exports = router;
