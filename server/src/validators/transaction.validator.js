/**
 * Basic request validation for transactions
 */
const validateCreateTransaction = (req, res, next) => {
  const userId = req.body.user_id || req.body.userId;
  const { amount } = req.body;

  if (!userId) {
    return res.status(400).json({
      success: false,
      message: 'user_id is required',
    });
  }
  req.body.user_id = userId;

  if (amount === undefined || amount === null || isNaN(Number(amount))) {
    return res.status(400).json({
      success: false,
      message: 'Valid amount is required',
    });
  }

  next();
};

const validateGetTransactions = (req, res, next) => {
  const { userId } = req.params;

  if (!userId) {
    return res.status(400).json({
      success: false,
      message: 'userId is required',
    });
  }

  next();
};

module.exports = {
  validateCreateTransaction,
  validateGetTransactions,
};
