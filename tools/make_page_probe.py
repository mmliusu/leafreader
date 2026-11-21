"""生成两个分页测试页（首页 / 中间页），用于 Edge headless 验证 CSS 多列分页是否成立。"""
import json
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = os.path.join(ROOT, "build")

style_src = open(os.path.join(ROOT, "LeafReader", "Reader", "ReaderStyle.swift"), encoding="utf-8").read()
start = style_src.index('#"""') + 4
end = style_src.index('"""#', start)
js = style_src[start:end]

CSS = """
html, body { background:#F5EBD8 !important; background-image:none !important; }
body {
  color:#3B2E1E !important;
  font-family:-apple-system, "PingFang SC", sans-serif !important;
  font-size:19px !important; line-height:1.75 !important; margin:0 !important;
  text-align:justify; word-wrap:break-word; overflow-wrap:break-word;
}
p, div, li, span { color:#3B2E1E !important; background-color:transparent !important; }
p { margin-bottom:0.85em !important; }
.leaf-p { text-indent:2em; margin:0 0 0.75em 0; }
html { height:100%; overflow-x:auto; overflow-y:hidden; }
body {
  height:100vh !important; box-sizing:border-box !important;
  padding:44px 0 34px 0 !important;
  column-width:100vw !important; column-gap:0 !important; column-fill:auto !important;
  overflow:visible !important;
}
body > * { padding-left:20px !important; padding-right:20px !important; box-sizing:border-box !important; max-width:100% !important; }
"""


def build_page(name: str, restore: float) -> str:
    paras = "".join(
        '<p class="leaf-p">第 %d 段。这是一段用于验证横向分页布局的中文测试文字，'
        '长度要足够填满一整页并溢出到下一列，这样才能判断列宽是否与视口一致、'
        '翻页步长是否正确，以及右边缘有没有被裁掉。</p>' % i
        for i in range(1, 261)
    )
    html = """<!DOCTYPE html>
<html><head><meta charset="utf-8"><title>init</title>
<meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
</head><body>
<div id="diag" style="position:fixed;top:0;left:0;right:0;z-index:99999;background:#fff;color:#c00;font:12px/1.4 monospace;padding:2px 4px;">diag</div>
%s
<script>%s</script>
<script>
window.addEventListener('load', function () {
  window.__leaf.applyConfig({ css: %s, mode: 'page', restore: %s, reset: %s });
  setTimeout(function () {
    var doc = document.documentElement;
    var total = Math.max(1, Math.round(doc.scrollWidth / window.innerWidth));
    var cur = Math.round(doc.scrollLeft / window.innerWidth);
    var info = 'iw=' + window.innerWidth + ' sw=' + doc.scrollWidth + ' bodyW=' + Math.round(document.body.getBoundingClientRect().width) + ' pages=' + total + ' cur=' + cur + ' sl=' + doc.scrollLeft;
    var d = document.getElementById('diag'); if (d) { d.textContent = info; }
    document.title = info;
  }, 700);
});
</script>
</body></html>""" % (paras, js, json.dumps(CSS, ensure_ascii=False), restore, "false" if restore else "true")
    path = os.path.join(BUILD, name)
    open(path, "w", encoding="utf-8").write(html)
    return path


os.makedirs(BUILD, exist_ok=True)
print(build_page("page_a.html", 0.0))
print(build_page("page_b.html", 0.5))
for ratio in (0.1, 0.3, 0.5, 0.9):
    print(build_page("page_%03d.html" % int(ratio * 100), ratio))