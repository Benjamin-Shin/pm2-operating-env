# generate-certs.ps1
# shared\.env 의 SSL_* 값으로 CA/서버 인증서를 만든다.
# 사용: .\generate-certs.ps1
# 히스토리: 2026-11 - 병원/앱 이름을 SSL_* 환경변수로 분리

$OutputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
if ($Host.Name -eq "ConsoleHost") { chcp 65001 | Out-Null }
$ErrorActionPreference = "Stop"

$SslDir = $PSScriptRoot
$SharedDir = Split-Path -Parent $SslDir
$OpEnvRoot = Split-Path -Parent $SharedDir
. (Join-Path $OpEnvRoot "env-config.ps1")

$map = Read-DotEnvFile (Join-Path $SharedDir ".env")

$country = Get-OpEnvValue $map "SSL_COUNTRY" "KR"
$state = Get-OpEnvValue $map "SSL_STATE" "Seoul"
$locality = Get-OpEnvValue $map "SSL_LOCALITY" "Ilwon"
$org = Get-OpEnvValue $map "SSL_ORG" "LocalOrg"
$ou = Get-OpEnvValue $map "SSL_OU" "IT Department"
$caOu = Get-OpEnvValue $map "SSL_CA_OU" "IT"
$cn = Get-OpEnvValue $map "SSL_CN" "localhost"
$caCn = Get-OpEnvValue $map "SSL_CA_CN" "Local Root CA"
$pfxName = Get-OpEnvValue $map "SSL_PFX_NAME" "$org Server"
$days = Get-OpEnvValue $map "SSL_DAYS" "365"
$bits = Get-OpEnvValue $map "SSL_KEY_BITS" "2048"
$dnsList = Get-OpEnvValue $map "SSL_SAN_DNS" "localhost,*.localhost"
$ipList = Get-OpEnvValue $map "SSL_SAN_IPS" "127.0.0.1,::1"
$installRoot = Get-OpEnvValue $map "SSL_INSTALL_ROOT" "true"
$verifyUrl = Get-OpEnvValue $map "SSL_VERIFY_URL" ""

if ($days -notmatch '^\d+$') { $days = "365" }
if ($bits -notmatch '^\d+$') { $bits = "2048" }

if ([string]::IsNullOrWhiteSpace($verifyUrl)) {
    $port = Get-OpEnvValue $map "APP_PORT" ""
    if ([string]::IsNullOrWhiteSpace($port)) { $port = Get-OpEnvValue $map "PORT" "" }
    if ([string]::IsNullOrWhiteSpace($port)) { $port = Get-OpEnvValue $map "INFUSESIGHT_PORT" "" }
    if ([string]::IsNullOrWhiteSpace($port)) { $port = Get-OpEnvValue $map "NEXT_PUBLIC_PORT" "3000" }
    $verifyUrl = "https://${cn}:$port/"
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $text = $Content.Replace("`r`n", "`n").TrimEnd("`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $text, $utf8)
}

function Split-CsvList {
    param([string]$Value)
    @($Value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

function Invoke-OpenSsl {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$OpenSslArgs)
    & openssl @OpenSslArgs
    if ($LASTEXITCODE -ne 0) {
        throw "openssl 실패 (exit $LASTEXITCODE)"
    }
}

if (-not (Get-Command openssl -ErrorAction SilentlyContinue)) {
    Write-Error "openssl 이 PATH에 없습니다."
}

$alt = New-Object System.Collections.Generic.List[string]
$dnsIndex = 1
foreach ($dns in (Split-CsvList $dnsList)) {
    $alt.Add(("DNS.{0} = {1}" -f $dnsIndex, $dns))
    $dnsIndex++
}
$ipIndex = 1
foreach ($ip in (Split-CsvList $ipList)) {
    $alt.Add(("IP.{0} = {1}" -f $ipIndex, $ip))
    $ipIndex++
}
if ($alt.Count -eq 0) {
    $alt.Add("DNS.1 = localhost")
    $alt.Add("IP.1 = 127.0.0.1")
}

$caCnf = @"
# generate-certs.ps1 이 shared/.env 의 SSL_* 값으로 다시 씁니다.
[ req ]
default_bits       = $bits
distinguished_name = req_distinguished_name
prompt             = no

[ req_distinguished_name ]
C  = $country
ST = $state
L  = $locality
O  = $org
OU = $caOu
CN = $caCn

[ v3_ca ]
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints       = critical,CA:true
keyUsage               = critical, digitalSignature, cRLSign, keyCertSign
"@

$sanBody = $alt -join "`n"
$sanCnf = @"
# generate-certs.ps1 이 shared/.env 의 SSL_* 값으로 다시 씁니다.
[ req ]
default_bits       = $bits
distinguished_name = req_distinguished_name
req_extensions     = v3_req
prompt             = no

[ req_distinguished_name ]
C  = $country
ST = $state
L  = $locality
O  = $org
OU = $ou
CN = $cn

[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names

[ alt_names ]
$sanBody
"@

$caCnfPath = Join-Path $SslDir "ca.cnf"
$sanCnfPath = Join-Path $SslDir "san.cnf"
Write-Utf8NoBom $caCnfPath $caCnf
Write-Utf8NoBom $sanCnfPath $sanCnf

$rootKey = Join-Path $SslDir "rootCA.key"
$rootCrt = Join-Path $SslDir "rootCA.crt"
$serverKey = Join-Path $SslDir "server.key"
$serverCsr = Join-Path $SslDir "server.csr"
$serverCrt = Join-Path $SslDir "server.crt"
$serverPfx = Join-Path $SslDir "server.pfx"

Write-Host "===== SSL 인증서 생성 ($org) ====="
Write-Host "작업 디렉토리: $SslDir"
Write-Host ""

Write-Host "1. 루트 CA 개인키 생성..."
Invoke-OpenSsl genrsa -out $rootKey $bits

Write-Host ""
Write-Host "2. 루트 CA 인증서 생성..."
Invoke-OpenSsl req -new -x509 -days $days -key $rootKey -out $rootCrt -config $caCnfPath -extensions v3_ca

Write-Host ""
Write-Host "3. 서버 개인키 생성..."
Invoke-OpenSsl genrsa -out $serverKey $bits

Write-Host ""
Write-Host "4. 서버 인증서 요청 생성..."
Invoke-OpenSsl req -new -key $serverKey -out $serverCsr -config $sanCnfPath

Write-Host ""
Write-Host "5. 서버 인증서 생성 (CA로 서명)..."
Invoke-OpenSsl x509 -req -in $serverCsr -CA $rootCrt -CAkey $rootKey -CAcreateserial -out $serverCrt -days $days -extensions v3_req -extfile $sanCnfPath

Write-Host ""
Write-Host "6. PFX 파일 생성..."
Invoke-OpenSsl pkcs12 -export -out $serverPfx -inkey $serverKey -in $serverCrt -certfile $rootCrt -name $pfxName -passout pass:

if ($installRoot -match '^(1|true|yes|y)$') {
    Write-Host ""
    Write-Host "7. 기존 CA 인증서 제거..."
    & certutil -delstore Root $caCn 2>&1 | Out-Null

    Write-Host ""
    Write-Host "8. 루트 CA를 신뢰할 수 있는 루트 인증서 저장소에 설치..."
    & certutil -addstore -f "Root" $rootCrt
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "루트 CA 설치에 실패했습니다. 관리자 권한으로 다시 실행하세요. 인증서 파일은 생성되어 있습니다."
    }
} else {
    Write-Host ""
    Write-Host "루트 CA 저장소 설치는 SSL_INSTALL_ROOT=$installRoot 라서 건너뜁니다."
}

Write-Host ""
Write-Host "===== 인증서 생성 완료 ====="
Write-Host "루트 CA: rootCA.crt ($caCn)"
Write-Host "서버 인증서: server.crt"
Write-Host "PFX 파일: server.pfx ($pfxName)"
Write-Host ""
Write-Host "브라우저에서 $verifyUrl 에 접속하면 신뢰할 수 있는 인증서로 인식됩니다."
