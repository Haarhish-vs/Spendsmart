const express = require('express');
const learningController = require('../controllers/learning.controller');

const router = express.Router();

router.get('/resources', learningController.getResources);

module.exports = router;
