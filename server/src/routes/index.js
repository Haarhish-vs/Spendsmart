const express = require('express');

const authRoutes = require('./auth.routes');
const dashboardRoutes = require('./dashboard.routes');
const transactionRoutes = require('./transaction.routes');
const budgetRoutes = require('./budget.routes');
const analyticsRoutes = require('./analytics.routes');
const aiPlanRoutes = require('./ai-plan.routes');
const learningRoutes = require('./learning.routes');
const notificationRoutes = require('./notification.routes');
const profileRoutes = require('./profile.routes');
const categoryRoutes = require('./category.routes');

const router = express.Router();

router.use('/auth', authRoutes);
router.use('/dashboard', dashboardRoutes);
router.use('/transactions', transactionRoutes);
router.use('/budgets', budgetRoutes);
router.use('/analytics', analyticsRoutes);
router.use('/categories', categoryRoutes);
router.use('/ai-plan', aiPlanRoutes);
router.use('/learning', learningRoutes);
router.use('/notifications', notificationRoutes);
router.use('/profile', profileRoutes);

module.exports = router;
