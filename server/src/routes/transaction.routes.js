const express = require('express');
const { createTransaction, getTransactions, getDashboardSummary, deleteTransaction } = require('../controllers/transaction.controller');
const { validateCreateTransaction, validateGetTransactions } = require('../validators/transaction.validator');

const router = express.Router();

router.post('/', validateCreateTransaction, createTransaction);
router.get('/summary/:userId', getDashboardSummary);
router.get('/:userId', validateGetTransactions, getTransactions);
router.delete('/:id', deleteTransaction);

module.exports = router;
