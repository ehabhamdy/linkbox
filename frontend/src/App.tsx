import React from 'react';
import { UploadForm } from './components/UploadForm';

function App() {
  return (
    <main style={{ fontFamily: 'sans-serif', maxWidth: 600, margin: '2rem auto' }}>
      <h1>LinkBox</h1>
      <p>Upload a file and get a shareable link.</p>
      <UploadForm />
      <footer style={{ marginTop: '3rem', fontSize: '0.8rem', opacity: 0.7 }}>
        <p>Minimal demo. Do not upload sensitive data.</p>
      </footer>
    </main>
  );
}

export default App;
