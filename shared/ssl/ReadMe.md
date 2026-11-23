# 서버인증서 만들기

## 루트 인증서(CA) 생성

```bash
openssl genrsa -out rootCA.key 2048
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem -subj "/CN=Localhost Root CA"

# 윈도우에서 실행하면 subj이 오류 발생하기도한다. 아래 명령어를 입력하면 수동으로 넣어야 하지만 어쨋든 된다.
openssl req -x509 -new -nodes -key rootCA.key -sha256 -days 1024 -out rootCA.pem

Country Name (2 letter code) [AU]:KO
State or Province Name (full name) [Some-State]:Seoul
Locality Name (eg, city) []:SeongBuk
Organization Name (eg, company) [Internet Widgits Pty Ltd]:TPHealthcare
Organizational Unit Name (eg, section) []:IT
Common Name (e.g. server FQDN or YOUR name) []:Localhost Root CA
Email Address []:

Please enter the following 'extra' attributes
to be sent with your certificate request
A challenge password []:
An optional company name []:
```

## 서버인증서 생성

```bash
openssl genrsa -out server.key 2048

openssl req -new -key server.key -out server.csr -config san.cnf

```

## 서버인증서 서명

```bash
openssl x509 -req -days 3650 -in server.csr -signkey server.key -out server.crt -extensions v3_req -extfile san.cnf
```

## pfx 파일생성

```bash
openssl pkcs12 -export -out server.pfx -inkey server.key -in server.crt -name "TPHealthcare Hub Cert"
```