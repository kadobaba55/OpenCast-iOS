import Foundation

/// TV ve tarayıcılara doğrudan sunulan yerleşik HTML5 oynatıcı kodu
public enum WebViewerTemplate {
    public static let html: String = """
    <!DOCTYPE html>
    <html lang="tr">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no">
      <title>OpenCast - TV Canlı Ekran</title>
      <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body, html {
          width: 100%; height: 100%;
          background-color: #000000;
          color: #ffffff;
          font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
          overflow: hidden;
          display: flex; flex-direction: column;
          align-items: center; justify-content: center;
        }
        #stream-container {
          position: relative; width: 100%; height: 100%;
          display: flex; align-items: center; justify-content: center;
          background: #000000;
        }
        #stream-img {
          max-width: 100%; max-height: 100%;
          width: auto; height: auto;
          object-fit: contain;
        }
        #overlay-bar {
          position: absolute; top: 16px; left: 50%;
          transform: translateX(-50%);
          background: rgba(20, 20, 20, 0.88);
          backdrop-filter: blur(12px);
          border: 1px solid rgba(255, 255, 255, 0.15);
          padding: 8px 22px; border-radius: 30px;
          display: flex; align-items: center; gap: 16px;
          font-size: 14px; z-index: 100;
          transition: opacity 0.5s ease;
        }
        #overlay-bar.autohide { opacity: 0; pointer-events: none; }
        .dot {
          width: 10px; height: 10px; border-radius: 50%;
          background: #22c55e; box-shadow: 0 0 8px #22c55e;
          animation: pulse 2s infinite;
        }
        .btn {
          background: #2563eb; color: #fff; border: none;
          padding: 6px 14px; border-radius: 16px;
          font-size: 13px; font-weight: 600; cursor: pointer;
        }
        .btn:focus, .btn:hover { background: #1d4ed8; outline: 2px solid #60a5fa; }
        #loading-state {
          position: absolute; display: flex; flex-direction: column;
          align-items: center; gap: 14px; color: #a1a1aa;
        }
        .spinner {
          width: 40px; height: 40px;
          border: 3px solid rgba(255, 255, 255, 0.1);
          border-top-color: #3b82f6; border-radius: 50%;
          animation: spin 1s linear infinite;
        }
        @keyframes spin { to { transform: rotate(360deg); } }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.4; } }
      </style>
    </head>
    <body>
      <div id="stream-container">
        <div id="loading-state">
          <div class="spinner"></div>
          <div>iPhone bekleniyor... Yayını başlatın</div>
        </div>
        <img id="stream-img" src="/stream" alt="Ekran" style="display: none;" />
      </div>

      <div id="overlay-bar">
        <div style="display: flex; align-items: center; gap: 6px;">
          <span class="dot" id="status-dot"></span>
          <span id="status-text">Canlı</span>
        </div>
        <span style="color: #52525b;">|</span>
        <span>1080p HD</span>
        <button class="btn" id="fullscreen-btn">Tam Ekran (Kumandadan OK)</button>
      </div>

      <script>
        const streamImg = document.getElementById('stream-img');
        const loadingState = document.getElementById('loading-state');
        const overlayBar = document.getElementById('overlay-bar');
        const fullscreenBtn = document.getElementById('fullscreen-btn');
        let hideTimer = null;

        function resetTimer() {
          overlayBar.classList.remove('autohide');
          clearTimeout(hideTimer);
          hideTimer = setTimeout(() => overlayBar.classList.add('autohide'), 3000);
        }

        document.addEventListener('mousemove', resetTimer);
        document.addEventListener('keydown', (e) => {
          resetTimer();
          if (e.key === 'Enter' || e.keyCode === 13) toggleFullscreen();
        });

        streamImg.onload = () => {
          loadingState.style.display = 'none';
          streamImg.style.display = 'block';
          resetTimer();
        };

        streamImg.onerror = () => {
          loadingState.style.display = 'flex';
          streamImg.style.display = 'none';
          setTimeout(() => { streamImg.src = '/stream?t=' + Date.now(); }, 1500);
        };

        function toggleFullscreen() {
          const doc = document.documentElement;
          if (!document.fullscreenElement && !document.webkitFullscreenElement) {
            if (doc.requestFullscreen) doc.requestFullscreen();
            else if (doc.webkitRequestFullscreen) doc.webkitRequestFullscreen();
            fullscreenBtn.innerText = 'Küçült';
          } else {
            if (document.exitFullscreen) document.exitFullscreen();
            else if (document.webkitExitFullscreen) document.webkitExitFullscreen();
            fullscreenBtn.innerText = 'Tam Ekran (OK)';
          }
        }

        fullscreenBtn.addEventListener('click', toggleFullscreen);
        fullscreenBtn.focus();
        resetTimer();
      </script>
    </body>
    </html>
    """
}
