# OperatingEnv - 웹서버 배포 가이드

릴리즈 폴더 + Junction + PM2로 **웹서버**를 운영하는 구조입니다.

앱 이름, 포트, 기동 파일, 압축 접두사, 인증서 주체는 스크립트에 적혀 있지 않습니다. `shared/.env`의 `PM2_APP_NAME`, `APP_PORT`, `APP_ENTRY`, `ARCHIVE_PREFIX`, `SSL_*`를 바꿉니다. 프로세스 환경변수가 있으면 그 값이 파일보다 우선입니다.

```
[빌드 PC]   배포 패키지 .7z
                ↓
[운영 서버]  OperatingEnv/releases + PM2 (HTTPS)
                ↓
           브라우저  https://<호스트>:<포트>
```

---

## 1. 폴더 구조

```
OperatingEnv/
├── releases/              # 빌드 타임스탬프별 (YYYYMMDD-HHMMSS)
│   └── 20260805-110951/   # 7z 루트 폴더와 동일
├── shared/
│   ├── .env               # 운영 환경변수 (필수)
│   ├── env.example
│   ├── runtime-config.json
│   ├── logs/              # PM2 로그
│   └── ssl/               # server.key / server.crt / rootCA.crt
├── Current                # Junction → releases/YYYYMMDD-HHMMSS
├── ecosystem.config.js
├── env-config.ps1 / env-config.sh
├── deploy.ps1 / switch-release.ps1 / init-current.ps1
├── start.ps1 / start.bat / start.sh
└── README.md
```

---

## 2. 운영 서버 준비

| 항목 | 내용 |
|------|------|
| OS | Windows 10/11. Linux에서는 `start.sh`, `switch-release.sh` |
| Node.js | LTS (PM2가 사용) |
| PM2 | `npm i -g pm2` |
| 7-Zip | 배포 압축 해제용 (PATH에 `7z`) |
| OpenSSL | `shared/ssl/generate-certs.bat`로 인증서를 만들 때 |

### 2.1 shared 설정

```powershell
cd OperatingEnv
copy shared\env.example shared\.env
# shared\.env 편집
```

스크립트가 읽는 값:

- `PM2_APP_NAME` — PM2 프로세스 이름. 비우면 `web-server`. 제품별 이름은 빌드에서 정하고, 여기에는 그 이름을 적는다
- `APP_PORT` — 웹 서버 포트. 없으면 `PORT`, `INFUSESIGHT_PORT`, `NEXT_PUBLIC_PORT`, 마지막 기본값 `3000`
- `APP_ENTRY` — `Current` 아래 기동 파일. 기본 `standalone-server.mjs`
- `APP_SERVER_JS` — 배포 시 같이 확인할 보조 파일. 기본 `server.js`. 없으면 경고만 하고 진행
- `ARCHIVE_PREFIX` — 구형 압축의 루트 폴더명. 기본 `standalone-deploy`
- `SSL_ORG`, `SSL_CA_CN`, `SSL_PFX_NAME`, `SSL_SAN_DNS`, `SSL_SAN_IPS` — `shared/ssl/generate-certs.bat`가 인증서를 만들 때 사용

DB, 인증, 화면 문구처럼 앱이 직접 읽는 값도 같은 `shared/.env`에 둡니다. 패키지에는 `.env`, `ssl`, `runtime-config.json`을 넣지 않습니다.

예시:

```env
PM2_APP_NAME=web-server
APP_PORT=3000
APP_ENTRY=standalone-server.mjs
ARCHIVE_PREFIX=standalone-deploy
```

### 2.2 SSL

`shared/ssl/` 에 배치:

- `server.key`, `server.crt`, `rootCA.crt`

자체 서명이면 **운영 서버에 rootCA를 신뢰 루트로 설치**해야 브라우저 경고 없이 열립니다.

```powershell
# 관리자 PowerShell — 로컬 컴퓨터 신뢰할 수 있는 루트에 설치
Import-Certificate -FilePath ".\shared\ssl\rootCA.crt" -CertStoreLocation Cert:\LocalMachine\Root
```

인증서 SAN/CN에 브라우저가 접속할 호스트명 또는 IP가 들어가 있어야 합니다. 새로 만들 때는 `shared\.env`의 `SSL_*`를 고친 뒤 `shared\ssl\generate-certs.bat`를 실행합니다.

### 2.3 PM2 부팅 자동 시작 (권장)

웹서버가 재부팅 후에도 떠 있어야 합니다.

```powershell
pm2 start ecosystem.config.js
pm2 save
# Windows: pm2-windows-startup 또는 작업 스케줄러로 `pm2 resurrect` 등록
npm i -g pm2-windows-startup
pm2-startup install
pm2 save
```

---

## 3. 배포 패키지 (빌드 PC)

산출물 예:

- `app-20260805-110951.7z`
- 파일명 안의 `YYYYMMDD-HHMMSS`가 릴리즈 폴더명이 됩니다.
- 구형 패키지는 압축 루트 폴더명이 `ARCHIVE_PREFIX`(기본 `standalone-deploy`)일 수 있습니다.

패키지에 **.env / ssl / runtime-config 은 포함되지 않습니다.** 운영 서버의 `OperatingEnv/shared`를 씁니다.

---

## 4. 배포 · PM2 기동 (운영 서버)

### 최초 1회

```powershell
cd OperatingEnv
.\deploy.ps1 -A "D:\path\to\app-20260805-110951.7z"
# → releases\20260805-110951 생성 후 Current 전환
.\start.ps1
pm2 status
```

`deploy.ps1`이 압축 해제 + `switch-release`까지 합니다. 파일명의 타임스탬프가 릴리즈 폴더명이 됩니다.

이미 Current만 바꿀 때는:

```powershell
.\switch-release.ps1 20260805-110951
```

릴리즈 폴더를 생략하면 `init-current.ps1`은 `releases`에서 이름이 가장 뒤인 폴더를 사용합니다.

### 업데이트 (다운타임 최소화)

1. 새 `.7z`를 `deploy.ps1`로 풀거나 `releases`에 직접 풉니다.
2. Current junction 전환과 `pm2 reload`는 `switch-release`가 합니다. 이어서 `pm2 save`를 하며, 저장본이 이미 같으면 건너뜁니다.
3. 접속 URL이 같으면 브라우저 새로고침으로 반영됩니다.

확인:

```powershell
pm2 status
pm2 logs web-server
# shared\.env 의 PM2_APP_NAME 을 사용
# 브라우저에서 https://<호스트>:<APP_PORT> 접속
```

---

## 5. 운영 체크리스트

**배포 시**

- [ ] 타임스탬프가 들어간 `.7z` 준비
- [ ] `deploy.ps1` 또는 releases 풀기 + `switch-release`
- [ ] `shared/.env` / `shared/ssl` 확인
- [ ] `start.ps1` → `pm2 status` OK
- [ ] `https://호스트:포트` 응답 확인

**운영 서버**

- [ ] rootCA 신뢰 설치 (자체서명 시)
- [ ] PM2 부팅 자동 시작
- [ ] `PM2_APP_NAME`, `APP_PORT`가 이 서버 기준인지 확인
- [ ] 앱이 쓰는 DB 등 외부 연결 확인

---

## 6. 스크립트 요약

| 스크립트 | 용도 |
|----------|------|
| `deploy.ps1 -A <7z>` / `deploy.bat` | 압축 해제 + 릴리즈 전환 |
| `switch-release.ps1 <날짜>` / `switch-release.sh` | Current 전환 + PM2 reload + save |
| `start.ps1` / `start.sh` | PM2로 HTTPS 웹서버 시작 + save |
| `init-current.ps1 [릴리즈폴더]` | 최초 Current junction |
| `releases/extract.ps1` / `extract.bat` | 압축만 풀 때 |
| `shared/ssl/generate-certs.bat` | `SSL_*`로 인증서 생성 |

PM2 프로세스 이름: `shared/.env`의 `PM2_APP_NAME`  
엔트리: `Current/<APP_ENTRY>` (기본 `standalone-server.mjs`, HTTPS)
