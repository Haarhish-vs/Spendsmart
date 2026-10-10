const { messaging } = require('../../config/firebase');

module.exports = {
  getMessagingClient: () => messaging,
};
