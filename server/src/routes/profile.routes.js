const express = require('express');
const profileController = require('../controllers/profile.controller');

const router = express.Router();

router.post('/onboarding', profileController.saveOnboarding);
router.get('/init', profileController.initializeUser);
router.get('/:userId', profileController.getProfile);

module.exports = router;
