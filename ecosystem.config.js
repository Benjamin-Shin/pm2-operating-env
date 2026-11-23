// OperatingEnv용 PM2 설정
// shared/.env 와 프로세스 환경변수를 읽는다.
// 우선순위: 프로세스 환경변수 > shared/.env > 기본값
//
// PM2_APP_NAME   프로세스 이름. 비어 있으면 web-server
// APP_PORT       포트. 없으면 PORT, INFUSESIGHT_PORT, NEXT_PUBLIC_PORT, 마지막 3000
// APP_ENTRY      Current 아래 기동 파일. 기본 standalone-server.mjs
// SSL_*_PATH     절대경로면 그대로 사용. 상대경로면 파일명만 shared/ssl 에 붙인다.
// LOG_DIR        절대경로면 그대로, 아니면 shared/logs
const fs = require('fs');
const path = require('path');

const OP_ENV_ROOT = __dirname;
const SHARED_DIR = path.join(OP_ENV_ROOT, 'shared');
const CURRENT_DIR = path.join(OP_ENV_ROOT, 'Current');

const loadEnvFile = () => {
  const envPath = path.join(SHARED_DIR, '.env');
  const env = {};
  if (fs.existsSync(envPath)) {
    const lines = fs.readFileSync(envPath, 'utf-8').split(/\r?\n/);
    for (const line of lines) {
      const t = line.trim().replace(/^\uFEFF/, '');
      if (!t || t.startsWith('#')) continue;
      const eq = t.indexOf('=');
      if (eq > 0) {
        const key = t.substring(0, eq).trim();
        let val = t.substring(eq + 1).trim();
        if ((val.startsWith('"') && val.endsWith('"')) || (val.startsWith("'") && val.endsWith("'")))
          val = val.slice(1, -1);
        env[key] = val;
      }
    }
  }
  return env;
};

const pick = (env, key) => {
  const fromProc = process.env[key];
  if (fromProc && String(fromProc).trim()) return String(fromProc).trim();
  if (env[key] && String(env[key]).trim()) return String(env[key]).trim();
  return '';
};

const resolvePm2Name = (env) => pick(env, 'PM2_APP_NAME') || 'web-server';

const resolveSharedFile = (envPath, dir, defaultName) => {
  if (envPath && path.isAbsolute(envPath)) return envPath;
  const name = envPath ? path.basename(envPath) : defaultName;
  return path.join(dir, name || defaultName);
};

const resolveAbs = (envPath, fallback) => {
  if (envPath && path.isAbsolute(envPath)) return envPath;
  return fallback;
};

const envFromFile = loadEnvFile();
const port = pick(envFromFile, 'APP_PORT')
  || pick(envFromFile, 'PORT')
  || pick(envFromFile, 'INFUSESIGHT_PORT')
  || pick(envFromFile, 'NEXT_PUBLIC_PORT')
  || '3000';
const pm2Name = resolvePm2Name(envFromFile);
const entry = path.basename(pick(envFromFile, 'APP_ENTRY') || 'standalone-server.mjs');

const sharedSsl = path.join(SHARED_DIR, 'ssl');
const sharedLogs = path.join(SHARED_DIR, 'logs');

const appEnv = {
  ...envFromFile,
  NODE_ENV: pick(envFromFile, 'NODE_ENV') || 'production',
  PORT: String(port),
  SSL_KEY_PATH: resolveSharedFile(pick(envFromFile, 'SSL_KEY_PATH'), sharedSsl, 'server.key'),
  SSL_CERT_PATH: resolveSharedFile(pick(envFromFile, 'SSL_CERT_PATH'), sharedSsl, 'server.crt'),
  SSL_CA_PATH: resolveSharedFile(pick(envFromFile, 'SSL_CA_PATH'), sharedSsl, 'rootCA.crt'),
  RUNTIME_CONFIG_PATH: resolveAbs(
    pick(envFromFile, 'RUNTIME_CONFIG_PATH'),
    path.join(SHARED_DIR, 'runtime-config.json')
  ),
  LOG_DIR: resolveAbs(pick(envFromFile, 'LOG_DIR'), sharedLogs),
  LOG_LEVEL: pick(envFromFile, 'LOG_LEVEL') || 'debug',
};

if (pick(envFromFile, 'INFUSESIGHT_PORT')) {
  appEnv.INFUSESIGHT_PORT = String(port);
}

module.exports = {
  apps: [
    {
      name: pm2Name,
      script: `./${entry}`,
      cwd: CURRENT_DIR,
      instances: 1,
      exec_mode: 'fork',
      env: appEnv,
      error_file: path.join(sharedLogs, 'pm2-error.log'),
      out_file: path.join(sharedLogs, 'pm2-out.log'),
      log_date_format: 'YYYY-MM-DD HH:mm:ss',
      log_type: 'raw',
      merge_logs: true,
      max_size: '50M',
      retain: 30,
      compress: true,
      dateFormat: 'YYYY-MM-DD_HH-mm',
      rotateInterval: '0 0 * * *',
      rotateModule: true,
      autorestart: true,
      max_restarts: 10,
      min_uptime: '10s',
      max_memory_restart: '1G',
      watch: false,
      ignore_watch: ['node_modules', 'logs', '.next'],
    },
  ],
};
