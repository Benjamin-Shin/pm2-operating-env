// 현재 PM2 프로세스 구성이 dump.pm2 와 같으면 save 를 건너뛴다.
// 비교는 이름, 실행 파일, 작업 디렉터리, 실행 모드, 운영에 쓰는 환경변수만 본다.
const { execFileSync } = require('child_process');
const fs = require('fs');
const os = require('os');
const path = require('path');

const STABLE_ENV = [
  'NODE_ENV',
  'PORT',
  'APP_PORT',
  'INFUSESIGHT_PORT',
  'SSL_KEY_PATH',
  'SSL_CERT_PATH',
  'SSL_CA_PATH',
  'RUNTIME_CONFIG_PATH',
  'LOG_DIR',
  'LOG_LEVEL',
  'PM2_APP_NAME',
];

function normalizePath(value) {
  if (!value) return '';
  return path.normalize(String(value)).replace(/[\\/]+$/, '').toLowerCase();
}

function pickEnv(source) {
  const env = {};
  if (!source) return env;
  for (const key of STABLE_ENV) {
    if (source[key] != null && String(source[key]) !== '') env[key] = String(source[key]);
  }
  return env;
}

function signatureOf(list) {
  return (Array.isArray(list) ? list : [])
    .map((proc) => {
      const runtime = proc.pm2_env || {};
      const env = pickEnv(runtime.env || proc.env || proc);
      return {
        name: proc.name || '',
        script: normalizePath(proc.pm_exec_path || runtime.pm_exec_path || proc.script || ''),
        cwd: normalizePath(proc.pm_cwd || proc.cwd || runtime.pm_cwd || ''),
        execMode: proc.exec_mode || runtime.exec_mode || '',
        env,
      };
    })
    .filter((proc) => proc.name)
    .sort((a, b) => a.name.localeCompare(b.name));
}

function dumpPath() {
  const home = process.env.PM2_HOME || path.join(os.homedir(), '.pm2');
  return path.join(home, 'dump.pm2');
}

function readDump() {
  const file = dumpPath();
  if (!fs.existsSync(file)) return [];
  return JSON.parse(fs.readFileSync(file, 'utf8'));
}

function readCurrent() {
  const raw = execFileSync('pm2', ['jlist'], { encoding: 'utf8', windowsHide: true });
  return JSON.parse(raw);
}

function needsSave() {
  return JSON.stringify(signatureOf(readCurrent())) !== JSON.stringify(signatureOf(readDump()));
}

function main() {
  let changed = true;
  try {
    changed = needsSave();
  } catch (err) {
    changed = true;
  }

  if (!changed) {
    console.log('  PM2 save는 이미 반영되어 있어 건너뜁니다.');
    return;
  }

  execFileSync('pm2', ['save'], { stdio: 'inherit', windowsHide: true });
  console.log('  PM2 save 완료');
}

if (require.main === module) {
  try {
    main();
  } catch (err) {
    console.error(err && err.message ? err.message : err);
    process.exit(1);
  }
}

module.exports = { needsSave, signatureOf };
