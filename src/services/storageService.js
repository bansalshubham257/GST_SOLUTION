// backend/src/services/storageService.js
// Handles file uploads to Supabase Storage or Firebase Storage

const { createClient } = require('@supabase/supabase-js');
const logger = require('../utils/logger');

let supabase;

const getSupabaseClient = () => {
  if (!supabase) {
    supabase = createClient(
      process.env.SUPABASE_URL,
      process.env.SUPABASE_SERVICE_KEY
    );
  }
  return supabase;
};

/**
 * Upload a file buffer to Supabase Storage
 */
const uploadFile = async ({ buffer, fileName, mimeType, bucket = 'gst-solution', path = '' }) => {
  try {
    const client = getSupabaseClient();
    const filePath = path ? `${path}/${fileName}` : fileName;

    const { data, error } = await client.storage
      .from(bucket)
      .upload(filePath, buffer, {
        contentType: mimeType,
        upsert: true,
      });

    if (error) throw error;

    const { data: urlData } = client.storage
      .from(bucket)
      .getPublicUrl(filePath);

    return { url: urlData.publicUrl, path: filePath };
  } catch (error) {
    logger.error('File upload failed:', error.message);
    throw error;
  }
};

/**
 * Delete a file from storage
 */
const deleteFile = async (filePath, bucket = 'gst-solution') => {
  try {
    const client = getSupabaseClient();
    const { error } = await client.storage.from(bucket).remove([filePath]);
    if (error) throw error;
  } catch (error) {
    logger.error('File delete failed:', error.message);
    throw error;
  }
};

/**
 * Get signed URL for private files
 */
const getSignedUrl = async (filePath, expiresIn = 3600, bucket = 'gst-solution') => {
  try {
    const client = getSupabaseClient();
    const { data, error } = await client.storage
      .from(bucket)
      .createSignedUrl(filePath, expiresIn);
    if (error) throw error;
    return data.signedUrl;
  } catch (error) {
    logger.warn('Signed URL generation failed:', error.message);
    return null;
  }
};

module.exports = { uploadFile, deleteFile, getSignedUrl };

