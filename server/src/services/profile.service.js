const profileRepository = require('../repositories/profile.repository');

class ProfileService {
  async getOrCreateUser(userId) {
    return await profileRepository.getOrCreateUser(userId);
  }

  async saveOnboarding(data) {
    let userId = data.user_id;
    const user = await profileRepository.getOrCreateUser(userId);
    userId = user.id;

    return await profileRepository.saveOnboarding(userId, data);
  }

  async getProfile(userId) {
    const user = await profileRepository.getOrCreateUser(userId);
    return await profileRepository.getProfile(user.id);
  }
}

module.exports = new ProfileService();
