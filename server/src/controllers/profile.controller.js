const profileService = require('../services/profile.service');

const saveOnboarding = async (req, res) => {
  try {
    const onboardingData = req.body;
    const result = await profileService.saveOnboarding(onboardingData);

    return res.status(200).json({
      success: true,
      message: 'Onboarding completed successfully',
      data: result,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to save onboarding data',
    });
  }
};

const getProfile = async (req, res) => {
  try {
    const { userId } = req.params;
    const profileData = await profileService.getProfile(userId);

    return res.status(200).json({
      success: true,
      data: profileData,
    });
  } catch (error) {
    return res.status(error.status || 500).json({
      success: false,
      message: error.message || 'Failed to fetch profile',
    });
  }
};

const initializeUser = async (req, res) => {
  try {
    const user = await profileService.getOrCreateUser(req.query.userId);
    return res.status(200).json({
      success: true,
      data: user,
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message || 'Failed to initialize user',
    });
  }
};

module.exports = {
  saveOnboarding,
  getProfile,
  initializeUser,
};
