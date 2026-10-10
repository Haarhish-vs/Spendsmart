const express = require('express');
const notificationController = require('../controllers/notification.controller');

const router = express.Router();

router.post('/device-token', notificationController.registerDeviceToken);
router.post('/test-push', notificationController.sendTestPush);
router.get('/:userId', notificationController.getAll);
router.get('/', notificationController.getAll);
router.patch('/:id/read', notificationController.markAsRead);

module.exports = router;
