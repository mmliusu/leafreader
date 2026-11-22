import Foundation

/// 注入到 WKWebView 里的阅读样式与脚本。
enum ReaderStyle {

    static func css(settings: ReadingSettings, pageMode: Bool, customFontURL: URL?) -> String {
        let theme = settings.theme
        let fontSize = Int(settings.fontSize.rounded())
        let lineHeight = String(format: "%.2f", settings.lineHeight)
        let margin = Int(settings.margin.rounded())
        let color = theme.foregroundHex
        let background = theme.backgroundHex

        var fontFace = ""
        if settings.font == .jinling, let url = customFontURL {
            fontFace = """
            @font-face {
              font-family: 'LeafCustom';
              src: url('\(url.absoluteString)') format('truetype');
              font-weight: normal;
              font-style: normal;
            }
            """
        }

        let base = fontFace + """
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

        if pageMode {
            return base + """
            html {
              height: 100%;
              overflow-x: auto;
              overflow-y: hidden;
            }
            body {
              height: 100vh !important;
              box-sizing: border-box !important;
              padding: 44px 0 34px 0 !important;
              column-width: 100vw !important;
              column-gap: 0 !important;
              column-fill: auto !important;
              overflow: visible !important;
            }
            body > * {
              padding-left: \(margin)px !important;
              padding-right: \(margin)px !important;
              box-sizing: border-box !important;
              max-width: 100% !important;
            }
            img, svg, video, table, pre, blockquote, figure {
              break-inside: avoid !important;
            }
            h1, h2, h3, h4, h5, h6 { break-after: avoid !important; }
            p { orphans: 2; widows: 2; }
            """
        }

        return base + """
        body { padding: 46px \(margin)px 104px \(margin)px !important; }
        """
    }

    static func configJSON(css: String, mode: String, restore: Double, reset: Bool) -> String {
        let payload = ConfigPayload(css: css, mode: mode, restore: restore, reset: reset)
        guard let data = try? JSONEncoder().encode(payload),
              let string = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return string
    }

    private struct ConfigPayload: Encodable {
        let css: String
        let mode: String
        let restore: Double
        let reset: Bool
    }

    static let bootstrapJS: String = #"""
    (function () {
      if (window.__leaf) { return; }

      var mode = 'scroll';
      var userScrolled = false;
      var lastRatio = -1;
      var lastPages = '';
      var timer = null;
      var touchStartX = 0;
      var touchStartY = 0;

      function pageStep() {
        return Math.max(1, window.innerWidth || 1);
      }

      function docScrollLeft() {
        return document.documentElement.scrollLeft || document.body.scrollLeft || 0;
      }

      function docScrollTop() {
        return document.documentElement.scrollTop || document.body.scrollTop || 0;
      }

      function maxScrollTop() {
        return Math.max(1, document.documentElement.scrollHeight - window.innerHeight);
      }

      function totalPages() {
        if (mode !== 'page') { return 1; }
        var width = document.documentElement.scrollWidth;
        return Math.max(1, Math.round(width / pageStep()));
      }

      function currentPage() {
        if (mode !== 'page') { return 0; }
        var total = totalPages();
        var index = Math.round(docScrollLeft() / pageStep());
        return Math.min(total - 1, Math.max(0, index));
      }

      function send(name, value) {
        try {
          if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers[name]) {
            window.webkit.messageHandlers[name].postMessage(value);
          }
        } catch (e) {}
      }

      function notifyPages(force) {
        if (mode !== 'page') { return; }
        var total = totalPages();
        var current = currentPage();
        var key = current + '/' + total;
        if (force || key !== lastPages) {
          lastPages = key;
          send('pages', { current: current, total: total });
        }
        var ratio = total > 1 ? current / (total - 1) : 0;
        if (force || Math.abs(ratio - lastRatio) > 0.0004) {
          lastRatio = ratio;
          send('progress', ratio);
        }
      }

      function notifyScroll(force) {
        if (mode === 'page') {
          notifyPages(force);
          return;
        }
        var ratio = Math.min(1, Math.max(0, docScrollTop() / maxScrollTop()));
        if (force || Math.abs(ratio - lastRatio) > 0.0004) {
          lastRatio = ratio;
          send('progress', ratio);
        }
      }

      var lastProgrammaticScroll = 0;

      function scrollWindow(x, y) {
        var currentX = window.scrollX || docScrollLeft();
        var currentY = window.scrollY || docScrollTop();
        if (Math.abs(currentX - x) < 1 && Math.abs(currentY - y) < 1) { return; }
        lastProgrammaticScroll = Date.now();
        window.scrollTo(x, y);
      }

      function onScroll() {
        if (Date.now() - lastProgrammaticScroll > 240) {
          userScrolled = true;
        }
        if (timer) { return; }
        timer = setTimeout(function () {
          timer = null;
          notifyScroll(false);
        }, mode === 'page' ? 120 : 260);
      }

      function ensureViewport() {
        var meta = document.querySelector('meta[name="viewport"]');
        if (!meta) {
          meta = document.createElement('meta');
          meta.setAttribute('name', 'viewport');
          (document.head || document.documentElement).appendChild(meta);
        }
        meta.setAttribute('content', 'width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no');
      }

      function applyConfig(cfg) {
        mode = cfg.mode === 'page' ? 'page' : 'scroll';
        ensureViewport();

        var root = document.documentElement;
        var style = document.getElementById('leaf-reader-style');
        if (!style) {
          style = document.createElement('style');
          style.id = 'leaf-reader-style';
          (document.head || root).appendChild(style);
        }
        style.textContent = cfg.css || '';

        userScrolled = false;
        lastRatio = -1;
        lastPages = '';

        var target = typeof cfg.restore === 'number' ? cfg.restore : 0;

        var place = function () {
          if (userScrolled) { return; }
          if (mode === 'page') {
            var total = totalPages();
            var page = cfg.reset ? 0 : Math.round(target * (total - 1));
            page = Math.min(total - 1, Math.max(0, page));
            scrollWindow(page * pageStep(), 0);
          } else {
            scrollWindow(0, cfg.reset ? 0 : Math.round(target * maxScrollTop()));
          }
        };

        place();
        setTimeout(place, 60);
        setTimeout(place, 200);
        setTimeout(place, 480);
        setTimeout(function () { notifyScroll(true); }, 520);
      }

      window.addEventListener('scroll', onScroll, { passive: true });

      window.addEventListener('resize', function () {
        setTimeout(function () { notifyScroll(true); }, 120);
      }, false);

      window.addEventListener('load', function () {
        setTimeout(function () { notifyScroll(true); }, 80);
      }, false);

      document.addEventListener('touchstart', function (event) {
        if (event.touches && event.touches.length === 1) {
          touchStartX = event.touches[0].clientX;
          touchStartY = event.touches[0].clientY;
        }
      }, { passive: true });

      document.addEventListener('touchend', function (event) {
        if (mode !== 'page') { return; }
        var touch = (event.changedTouches && event.changedTouches[0]) ? event.changedTouches[0] : null;
        if (!touch) { return; }
        var dx = touch.clientX - touchStartX;
        var dy = touch.clientY - touchStartY;
        if (Math.abs(dx) < 44 || Math.abs(dx) < Math.abs(dy)) { return; }
        var total = totalPages();
        var current = currentPage();
        if (dx < 0 && current >= total - 1) { send('chapter', 'next'); }
        if (dx > 0 && current <= 0) { send('chapter', 'prev'); }
      }, { passive: true });

      document.addEventListener('click', function (event) {
        var target = event.target;
        if (target && typeof target.closest === 'function' && target.closest('a')) { return; }
        var selection = window.getSelection ? String(window.getSelection()) : '';
        if (selection.length > 0) { return; }
        if (mode === 'page') {
          var width = window.innerWidth || 1;
          var x = event.clientX / width;
          if (x < 0.22) { send('page', -1); return; }
          if (x > 0.78) { send('page', 1); return; }
        }
        send('tap', true);
      }, false);

      window.__leaf = {
        applyConfig: applyConfig,
        clearMarks: function () {
          var marks = document.querySelectorAll('mark.leaf-hit');
          for (var i = 0; i < marks.length; i++) {
            var mark = marks[i];
            var parent = mark.parentNode;
            if (!parent) { continue; }
            var textNode = document.createTextNode(mark.textContent || '');
            parent.replaceChild(textNode, mark);
            parent.normalize();
          }
        },
        findAndScroll: function (term) {
          if (!term) { return ''; }
          var query = String(term).toLowerCase();
          try { window.__leaf.clearMarks(); } catch (e) {}
          var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
          var node;
          while ((node = walker.nextNode())) {
            var value = node.nodeValue || '';
            var index = value.toLowerCase().indexOf(query);
            if (index < 0) { continue; }
            var range = document.createRange();
            try {
              range.setStart(node, index);
              range.setEnd(node, index + query.length);
            } catch (e) { continue; }
            var rect = range.getBoundingClientRect();
            var mark = document.createElement('mark');
            mark.className = 'leaf-hit';
            mark.style.backgroundColor = 'rgba(255, 214, 0, 0.55)';
            mark.style.color = 'inherit';
            var rest = node.splitText(index);
            var target = rest.splitText(query.length);
            var copy = target.cloneNode(true);
            mark.appendChild(copy);
            target.parentNode.replaceChild(mark, target);
            if (mode === 'page') {
              var left = window.scrollX + rect.left;
              var page = Math.floor(left / pageStep());
              window.scrollTo(page * pageStep(), 0);
            } else {
              window.scrollTo(0, window.scrollY + rect.top - 100);
            }
            return '1';
          }
          return '';
        },
        currentRatio: function () {
          if (mode === 'page') {
            var total = totalPages();
            return total > 1 ? currentPage() / (total - 1) : 0;
          }
          return Math.min(1, Math.max(0, docScrollTop() / maxScrollTop()));
        },
        goPage: function (delta) {
          if (mode !== 'page' || !delta) { return; }
          var total = totalPages();
          var current = currentPage();
          var target = Math.min(total - 1, Math.max(0, current + delta));
          if (target === current) {
            if (delta > 0) { send('chapter', 'next'); }
            else { send('chapter', 'prev'); }
            return;
          }
          lastProgrammaticScroll = Date.now() + 400;
          window.scrollTo({ left: target * pageStep(), top: 0, behavior: 'smooth' });
        }
      };
    })();
    """#
}