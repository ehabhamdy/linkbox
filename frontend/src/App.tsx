import { UploadForm } from './components/UploadForm';

function App() {
  return (
    <div className="app-container">
      <main className="main-content">
        <div className="header">
          <div className="logo">
            <span className="logo-icon">📦</span>
            <h1>LinkBox</h1>
          </div>
          <p className="subtitle">Secure file sharing with temporary links</p>
        </div>
        
        <UploadForm />
        
        <footer className="footer">
          <div className="info-cards">
            <div className="info-card">
              <span className="info-icon">🔒</span>
              <span className="info-text">Private S3 Storage</span>
            </div>
            <div className="info-card">
              <span className="info-icon">⏱️</span>
              <span className="info-text">5-Minute Expiry</span>
            </div>
            <div className="info-card">
              <span className="info-icon">🚀</span>
              <span className="info-text">CloudFront CDN</span>
            </div>
          </div>
          <p className="disclaimer">Demo application • Do not upload sensitive data</p>
        </footer>
      </main>
    </div>
  );
}

export default App;
