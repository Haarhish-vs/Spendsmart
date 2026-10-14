const express = require('express');
const authController = require('../controllers/auth.controller');
const authValidator = require('../validators/auth.validator');
const authMiddleware = require('../middleware/auth.middleware');

const router = express.Router();

router.post('/register', authValidator.validateRegister, authController.register);
router.post('/login', authValidator.validateLogin, authController.login);
router.get('/me', authMiddleware, authController.getCurrentUser);

module.exports = router;
