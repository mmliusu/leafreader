// 用 Node 模拟 Legado 运行时，验证私有书源 jsLib 是否依赖 Android 独有能力
const fs = require('fs');
const vm = require('vm');
const { execSync } = require('child_process');

const src = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'))[0];
const header = src.header ? JSON.parse(src.header) : {};
const headerArgs = Object.entries(header)
  .map(([k, v]) => `-H "${k}: ${String(v).replace(/"/g, '\\"')}"`)
  .join(' ');

function curl(raw) {
  let url = String(raw);
  let opts = {};
  const idx = url.indexOf(",{");
  if (idx > 0) {
    try { opts = JSON.parse(url.slice(idx + 1)); url = url.slice(0, idx); } catch (e) {}
  }
  const method = (opts.method || 'GET').toUpperCase();
  const extra = Object.entries(opts.headers || {})
    .map(([k, v]) => `-H "${k}: ${String(v).replace(/"/g, '\\"')}"`)
    .join(' ');
  const bodyFile = `${require('os').tmpdir()}\\leaf-body.json`;
  const resolveArgs = process.env.PROBE_RESOLVE ? `--resolve "${process.env.PROBE_RESOLVE}"` : "";
  let cmd = `curl -s -L -4 --max-time 25 -A "okhttp/4.12.0" ${resolveArgs} ${headerArgs} ${extra} -X ${method}`;
  if (opts.body) {
    require('fs').writeFileSync(bodyFile, String(opts.body));
    cmd += ` --data-binary @"${bodyFile}"`;
  }
  cmd += ` "${url}"`;
  try {
    return execSync(cmd, { encoding: 'utf8', maxBuffer: 20 * 1024 * 1024 });
  } catch (e) {
    return '';
  }
}

const calls = [];
const java = {
  ajax: function (a, b) {
    const url = typeof a === 'string' ? a : (a && a.url);
    calls.push(url);
    return curl(url);
  },
  base64DecodeToString: (s) => Buffer.from(String(s), 'base64').toString('utf8'),
  base64Encode: (s) => Buffer.from(String(s), 'utf8').toString('base64'),
  base64Decode: (s) => Buffer.from(String(s), 'base64'),
  getSource: () => src,
  getDeviceId: () => 'emulator-device-id',
  getAndroidId: () => '9774d56d682e549c',
  getImei: () => '',
  getSerial: () => 'unknown',
  getDeviceModel: () => 'Pixel 5',
  getActivity: () => ({}),
  getContext: () => ({}),
  toast: (s) => console.error('[toast]', s),
  longToast: (s) => console.error('[longToast]', s),
  log: (...a) => console.error('[log]', ...a),
  setTimeout: (fn, ms) => setTimeout(fn, ms),
  clearTimeout: (id) => clearTimeout(id),
  util: {
    MD5: (s) => require('crypto').createHash('md5').update(String(s)).digest('hex'),
    Hex: (s) => Buffer.from(String(s), 'utf8').toString('hex'),
  },
};

const ctx = vm.createContext({
  java,
  source: src,
  cookie: { getCookie: () => '', setCookie: () => {}, removeCookie: () => {} },
  Packages: { java: { security: { MessageDigest: function () {} } } },
  console,
  setTimeout,
  clearTimeout,
  key: process.argv[3] || '斗破苍穹',
  page: 1,
  result: null,
  baseUrl: src.bookSourceUrl,
  book: null,
  chapter: null,
});

try {
  vm.runInContext(src.jsLib || '', ctx, { timeout: 20000 });
  console.error('[ok] jsLib evaluated');
} catch (e) {
  console.error('[jsLib error]', e.message);
  process.exit(1);
}

try {
  const searchUrl = vm.runInContext(`MDSearchUrl(${JSON.stringify(process.argv[3] || '斗破苍穹')}, 1)`, ctx, { timeout: 60000 });
  console.error('[searchUrl]', String(searchUrl).slice(0, 200));
  const body = curl(String(searchUrl));
  console.error('[response length]', body.length);
  console.log(body.slice(0, 600));
} catch (e) {
  console.error('[eval error]', e.message);
}
console.error('[ajax calls]', calls.length, calls.slice(0, 3));