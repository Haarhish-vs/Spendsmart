const supabase = require('../config/supabase');

const getAll = async (req, res) => {
  try {
    const { data, error } = await supabase
      .from('categories')
      .select('*')
      .order('name', { ascending: true });

    if (error) throw error;

    return res.status(200).json({
      success: true,
      data: data || [],
    });
  } catch (error) {
    return res.status(500).json({
      success: false,
      message: error.message || 'Failed to fetch categories',
    });
  }
};

module.exports = {
  getAll,
};
