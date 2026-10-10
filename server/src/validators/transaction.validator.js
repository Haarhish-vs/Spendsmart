/**
 * Basic request validation for transactions
 */
const validateCreateTransaction = (req, res, next) => {
  const { user_id, amount } = req.body;

  if (!user_id) {
    return res.status(400).json({
      success: false,
      message: 'user_id is required',
    });
  }

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
