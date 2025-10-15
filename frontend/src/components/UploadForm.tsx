import React, { useState } from 'react';
import axios from 'axios';

export const UploadForm: React.FC = () => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [sharedLink, setSharedLink] = useState<string>('');
  const [error, setError] = useState<string>('');

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setSelectedFile(e.target.files[0]);
      setSharedLink('');
      setError('');
    }
  };

  const handleUpload = async () => {
    if (!selectedFile) return;
    setUploading(true);
    setError('');

    try {
      // Step 1: ask backend for presigned form data
      const presignResp = await axios.post('/api/generate-presigned-url', {
        filename: selectedFile.name,
        content_type: selectedFile.type || 'application/octet-stream',
        size_bytes: selectedFile.size,
      });

      console.log('Backend response:', presignResp.data);

      const { upload_url, form_fields, download_url } = presignResp.data;

      if (!form_fields) {
        console.error('Missing form_fields in response:', presignResp.data);
        throw new Error('Invalid response from server: missing form_fields');
      }

      const formData = new FormData();
      Object.entries(form_fields).forEach(([k, v]) => formData.append(k, v as string));
      formData.append('file', selectedFile);

      await axios.post(upload_url, formData, {
        headers: { 'Content-Type': 'multipart/form-data' },
      });

      setSharedLink(download_url);
    } catch (err: any) {
      console.error('Upload error:', err);
      setError(err.message || 'Upload failed');
    } finally {
      setUploading(false);
    }
  };

  return (
    <section style={{ border: '1px solid #ddd', padding: '1rem', borderRadius: 4 }}>
      <input type="file" onChange={handleFileChange} />
      <button onClick={handleUpload} disabled={!selectedFile || uploading} style={{ marginLeft: '0.5rem' }}>
        {uploading ? 'Uploading...' : 'Upload'}
      </button>
      {error && <p style={{ color: 'red' }}>{error}</p>}
      {sharedLink && (
        <p>
          Link: <a href={sharedLink} target="_blank" rel="noopener noreferrer">{sharedLink}</a>
        </p>
      )}
    </section>
  );
};
