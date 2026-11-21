import Foundation

/// 注入到 WKWebView 里的阅读样式与脚本。
enum ReaderStyle {

    static func css(settings: ReadingSettings) -> String {
        let theme = settings.theme
        let fontSize = Int(settings.fontSize.rounded())
        let lineHeight = String(format: "%.2f", settings.lineHeight)
        let margin = Int(settings.margin.rounded())
        let color = theme.foregroundHex
        let background = theme.backgroundHex

        return """
        html, body {
          background: \(background) !important;
          background-color: \(background) !important;
          background-image: none !important;
        }
        body {
          color: \(color) !important;
          font-family: \(settings.font.cssFamily) !important;
          font-size: \(fontSize)px !important;
          line-height: \(lineHeight) !important;
          margin: 0 !important;
          padding: 46px \(margin)px 104px \(margin)px !important;
          text-align: justify;
          -webkit-text-size-adjust: 100%;
          word-wrap: break-word;
          overflow-wrap: break-word;
        }
        p, div, section, article, li, td, th, dd, blockquote,
        h1, h2, h3, h4, h5, h6, span, strong, em, b, i {
          color: \(color) !important;
          background-color: transparent !important;
        }
        p { margin-bottom: 0.85em !important; }
        h1, h2, h3, h4, h5, h6 { line-height: 1.45 !important; }
        img, svg, video, canvas { max-width: 100% !important; height: auto !important; }
        a, a * { color: \(theme.linkHex) !important; text-decoration: none !important; }
        table { max-width: 100% !important; border-collapse: collapse; }
        pre, code { white-space: pre-wrap !important; word-break: break-word; }
        hr { border: 0; border-top: 1px solid \(theme.linkHex)33; margin: 1.2em 0; }
        .leaf-p { text-indent: 2em; margin: 0 0 0.75em 0; }
        .leaf-gap { height: 0.4em; }
        ::selection { background: \(theme.linkHex)33; }
        """
    }

    static func configJSON(css: String, restore: Double, reset: Bool) -> String {
        let payload = ConfigPayload(css: css, restore: restore, reset: reset)
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private struct ConfigPayload: Encodable {
        let css: String
        let restore: Double
        let reset: Bool
    }

    static let bootstrapJS: String = #"""
    (function () {
      if (window.__leaf) { return; }

      var userScrolled = false;
      var lastRatio = -1;
      var timer = null;

      function maxScroll() {
        var doc = document.documentElement;
        return Math.max(1, doc.scrollHeight - window.innerHeight);
      }

      function ratio() {
        return Math.min(1, Math.max(0, (window.scrollY || docScrollTop()) / maxScroll()));
      }

      function docScrollTop() {
        return document.documentElement.scrollTop || document.body.scrollTop || 0;
      }

      function send(name, value) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
            window.webkit.messageHandlers[name].postMessage(value);
          }
        } catch (e) {}
      }

      function notifyProgress(force) {
        var r = ratio();
        if (!force && Math.abs(r - lastRatio) < 0.0004) { return; }
        lastRatio = r;
        send('progress', r);
      }

      function onScroll() {
        userScrolled = true;
        if (timer) { return; }
        timer = setTimeout(function () {
          timer = null;
          notifyProgress(false);
        }, 260);
      }

      function applyConfig(cfg) {
        var root = document.documentElement;
        var style = document.getElementById('leaf-reader-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'leaf-reader-style';
          (document.head || root).appendChild(style);
        }
        style.textContent = cfg.css || '';

        if (cfg.reset) {
          window.scrollTo(0, 0);
        } else if (typeof cfg.restore === 'number' && cfg.restore > 0.0004) {
          var applyRestore = function () {
            if (userScrolled) { return; }
            window.scrollTo(0, Math.round(cfg.restore * maxScroll()));
          };
          applyRestore();
          setTimeout(applyRestore, 120);
          setTimeout(applyRestore, 420);
        }

        lastRatio = ratio();
        send('ready', lastRatio);
      }

      window.addEventListener('scroll', onScroll, { passive: true });
      window.addEventListener('resize', function () { notifyProgress(true); }, false);
      window.addEventListener('load', function () {
        setTimeout(function () { notifyProgress(true); }, 80);
      }, false);

      document.addEventListener('click', function (event) {
        var target = event.target;
        if (target && typeof target.closest === 'function' && target.closest('a')) { return; }
        var selection = window.getSelection ? String(window.getSelection()) : '';
        if (selection.length > 0) { return; }
        send('tap', true);
      }, false);

      window.__leaf = {
        applyConfig: applyConfig,
        currentRatio: ratio,
        scrollToRatio: function (value) {
          if (typeof value !== 'number') { return; }
          var clamped = Math.min(1, Math.max(0, value));
          window.scrollTo(0, Math.round(clamped * maxScroll()));
          userScrolled = false;
          notifyProgress(true);
        }
      };
    })();
    """#
}