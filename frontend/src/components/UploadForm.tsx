import React, { useState } from 'react';
import axios from 'axios';

export const UploadForm: React.FC = () => {
  const [selectedFile, setSelectedFile] = useState<File | null>(null);
  const [uploading, setUploading] = useState(false);
  const [sharedLink, setSharedLink] = useState<string>('');
  const [error, setError] = useState<string>('');
  const [copied, setCopied] = useState(false);

  const handleFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    if (e.target.files && e.target.files.length > 0) {
      setSelectedFile(e.target.files[0]);
      setSharedLink('');
      setError('');
      setCopied(false);
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

  const copyToClipboard = () => {
    navigator.clipboard.writeText(sharedLink);
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const formatFileSize = (bytes: number) => {
    if (bytes < 1024) return bytes + ' B';
    if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + ' KB';
    return (bytes / (1024 * 1024)).toFixed(1) + ' MB';
  };

  return (
    <div className="upload-container">
      <div className="upload-card">
        <div className="file-input-wrapper">
          <input
            type="file"
            id="file-upload"
            onChange={handleFileChange}
            className="file-input"
          />
          <label htmlFor="file-upload" className="file-input-label">
            <span className="upload-icon">📁</span>
            <span className="upload-text">
              {selectedFile ? selectedFile.name : 'Choose a file'}
            </span>
            {selectedFile && (
              <span className="file-size">{formatFileSize(selectedFile.size)}</span>
            )}
          </label>
        </div>

        <button
          onClick={handleUpload}
          disabled={!selectedFile || uploading}
          className={`upload-button ${uploading ? 'uploading' : ''}`}
        >
          {uploading ? (
            <>
              <span className="spinner"></span>
              Uploading...
            </>
          ) : (
            <>
              <span>⬆️</span>
              Upload File
            </>
          )}
        </button>

        {error && (
          <div className="message error-message">
            <span>❌</span>
            {error}
          </div>
        )}

        {sharedLink && (
          <div className="success-container">
            <div className="message success-message">
              <span>✅</span>
              File uploaded successfully!
            </div>
            <div className="link-container">
              <div className="link-header">
                <span>🔗 Share this link (expires in 5 minutes):</span>
              </div>
              <div className="link-box">
                <input
                  type="text"
                  value={sharedLink}
                  readOnly
                  className="link-input"
                  onClick={(e) => (e.target as HTMLInputElement).select()}
                />
                <button onClick={copyToClipboard} className="copy-button">
                  {copied ? '✓ Copied!' : '📋 Copy'}
                </button>
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
};
