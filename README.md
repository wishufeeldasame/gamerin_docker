# Gamerin Docker 

## 기준 경로

```text
~/capstone
├── backend
├── frontend
├── docker
│   └── nginx
│   └── scripts
├── data
│   ├── postgres
│   ├── tmp
│   └── uploads
└── backups
```

운영 명령은 기본적으로 Docker repo에서 실행

```bash
cd ~/capstone/docker
```

스크립트도 기본적으로 `$HOME/capstone`을 사용.

```bash
GAMERIN_BASE_DIR=/path/to/capstone ./scripts/deploy.sh
```

## 구성 파일

- `docker-compose.yml`: docker compose 정의
- `docker-compose.prod.yml`: 도메인(HTTPS) 배포 전용 override. Caddy 추가, nginx 호스트 포트 비공개
- `Caddyfile`: `gamerin.live` HTTPS 입구(Caddy) 설정
- `nginx/default.conf`: 프론트/백엔드 reverse proxy 설정
- `.env`: 환경변수 파일
- `.env.example`: `.env` 작성 기준 예시
- `Caddyfile.example`: Caddy reverse proxy 예시
- `scripts/deploy.sh`: 이미지 빌드 후 전체 서비스 기동
- `scripts/logs.sh`: 서비스 로그 확인
- `scripts/down.sh`: 전체 서비스 중지
- `scripts/backup-postgres.sh`: DB 백업
- `scripts/restore-postgres.sh`: DB 복원
- `scripts/reset-db.sh`: 오류 대응용 DB 초기화

`.env`는 GitHub에 올리지 않는다.

## 현재 상태 확인

```bash
cd ~/capstone/docker
docker compose ps
```

컨테이너 로그를 짧게 확인하려면:

```bash
docker compose logs --tail=100 nginx
docker compose logs --tail=100 backend
docker compose logs --tail=100 frontend
docker compose logs --tail=100 postgres
```

실시간 로그를 보려면:

```bash
./scripts/logs.sh nginx
./scripts/logs.sh backend
./scripts/logs.sh frontend
```

종료는 `Ctrl + C`

## 전체 배포

백엔드, 프론트엔드, Docker 설정을 모두 최신으로 가져온 뒤 배포

```bash
cd ~/capstone/backend
git pull

cd ~/capstone/frontend
git pull

cd ~/capstone/docker
git pull
./scripts/deploy.sh
```

`deploy.sh`는 아래 작업을 수행함

```bash
docker compose --env-file .env build backend frontend
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

접속 주소는 하나만 사용합니다.

```text
운영: https://gamerin.live   (Caddy → nginx, docker-compose.prod.yml)
로컬: http://localhost       (nginx, docker-compose.yml)
```

프론트는 `/api/...` 상대경로로 백엔드를 호출하고, nginx가 `/api` 요청을 백엔드로 전달합니다.

프로필 이미지 업로드 경로는 일반 API보다 작은 요청 제한을 적용합니다.

```text
/api/v1/users/me/profile-images
```

- `client_max_body_size 6m`
- IP 기준 `30r/m`, burst `10`

게시물 생성 경로는 백엔드의 영상 업로드 정책과 맞춰 더 큰 요청 제한을 적용합니다.

```text
/api/v1/posts
```

- `client_max_body_size 530m`
- IP 기준 `10r/m`, burst `5`

## 백엔드만 배포

백엔드 코드만 바뀐 경우:

```bash
cd ~/capstone/backend
git pull

cd ~/capstone/docker
docker compose build backend
docker compose up -d backend
docker compose logs --tail=100 -f backend
```

백엔드는 `SPRING_PROFILES_ACTIVE=prod`로 실행됨. 서버 배포에서는 `application-local.yaml`을 사용하지 않음.

## 프론트엔드만 배포

프론트엔드 코드만 바뀐 경우:

```bash
cd ~/capstone/frontend
git pull

cd ~/capstone/docker
docker compose build frontend
docker compose up -d frontend
docker compose logs --tail=100 -f frontend
```

`NEXT_PUBLIC_API_BASE_URL` 값을 `.env`에서 바꿨다면 반드시 `docker compose build frontend`를 다시 실행해야 함.

## Docker 설정만 반영

`docker-compose.yml`, 스크립트, `.env.example` 같은 Docker repo 변경만 반영할 때:

```bash
cd ~/capstone/docker
git pull
docker compose up -d
docker compose ps
```

이미지 빌드 설정이 바뀐 경우에는 다시 빌드함

```bash
docker compose build backend frontend
docker compose up -d
```

## 환경변수 수정

`~/capstone/docker/.env`에서 관리

```bash
cd ~/capstone/docker
nano .env
```

수정 후 반영:

```bash
docker compose up -d
```

프론트 빌드 변수인 `NEXT_PUBLIC_API_BASE_URL`을 바꾼 경우:

```bash
docker compose build frontend
docker compose up -d frontend
```

`.env.example`은 운영 서버(`https://gamerin.live`) 기준 값이고, 로컬 개발 값은 `# local:` 주석에 있다.

운영 서버:

```dotenv
NEXT_PUBLIC_API_BASE_URL=
CORS_ALLOWED_ORIGINS=https://gamerin.live
FRONTEND_BASE_URL=https://gamerin.live
REFRESH_COOKIE_SECURE=true
STREAM_TOKEN_COOKIE_SECURE=true
```

로컬 `http://localhost` 개발:

```dotenv
NGINX_BIND=127.0.0.1
NGINX_PORT=80
NEXT_PUBLIC_API_BASE_URL=
CORS_ALLOWED_ORIGINS=http://localhost
FRONTEND_BASE_URL=http://localhost
REFRESH_COOKIE_SECURE=false
STREAM_TOKEN_COOKIE_SECURE=false
```

- `NEXT_PUBLIC_API_BASE_URL`은 빈 값으로 둡니다. 그래야 프론트가 절대주소가 아니라 `/api/...` 상대경로로 호출합니다.
- 운영에서는 `docker-compose.prod.yml`이 nginx 호스트 포트를 닫으므로 `NGINX_BIND`·`NGINX_PORT`는 로컬에서만 쓰인다.
- `JWT_SECRET`은 로컬·운영 모두 `openssl rand -base64 48`로 새로 만든다. `.env.example`의 placeholder는 32바이트 미만이라 그대로 두면 백엔드가 기동하지 않는다.
- 필수값 `CORS_ALLOWED_ORIGINS`, `FRONTEND_BASE_URL`, `JWT_SECRET`, `GOOGLE_OAUTH_CLIENT_ID`, `GOOGLE_OAUTH_CLIENT_SECRET`, `DB_NAME`, `DB_USERNAME`, `DB_PASSWORD`가 비어 있으면 `docker compose` 명령이 `... is required`로 실패한다. `docker compose --env-file .env config --quiet`로 먼저 확인할 수 있다.

## 서버 재시작

전체 서비스 재시작:

```bash
cd ~/capstone/docker
docker compose restart
```

특정 서비스만 재시작:

```bash
docker compose restart nginx
docker compose restart backend
docker compose restart frontend
docker compose restart postgres
```

## 서버 내리기

전체 컨테이너를 내림. DB 데이터와 업로드 파일은 유지됨.

```bash
cd ~/capstone/docker
./scripts/down.sh
```

다시 올리려면:

```bash
docker compose up -d
```

운영 서버에서 `docker compose down -v`는 DB volume 삭제로 이어질 수 있어서 사용x

## DB 백업과 복원

백업:

```bash
cd ~/capstone/docker
./scripts/backup-postgres.sh
```

백업 파일은 `~/capstone/backups/postgres-YYYYMMDD-HHMMSS.sql` 형식으로 생성됨

복원:

```bash
cd ~/capstone/docker
./scripts/restore-postgres.sh ~/capstone/backups/postgres-YYYYMMDD-HHMMSS.sql
```

복원은 현재 DB에 데이터를 다시 쓰는 작업. 운영 데이터에 실행하기 전에는 반드시 최근 백업을 하나 더 만들어둠.

## 개발 DB 초기화

Flyway 마이그레이션 충돌이나 개발 DB 꼬임 때문에 DB 파일만 지우고 싶을 때 사용. 이 스크립트는 Postgres 데이터 폴더만 삭제함

```bash
cd ~/capstone/docker
./scripts/reset-db.sh
```


## 데이터 경로

- DB 데이터: `~/capstone/data/postgres`
- 업로드 파일: `~/capstone/data/uploads`
- 백엔드 임시 파일: `~/capstone/data/tmp`
- DB 백업 파일: `~/capstone/backups`

피드 이미지나 업로드 파일은 `~/capstone/data/uploads`에 남음. 컨테이너를 다시 만들거나 이미지를 다시 빌드해도 이 폴더는 유지됨

## 권한 문제

백엔드 컨테이너는 UID `10001` 사용자로 실행됨. 업로드나 임시 파일 생성에서 권한 오류가 나면 서버에서 아래를 실행한다.

```bash
sudo chown -R 10001:10001 ~/capstone/data/uploads ~/capstone/data/tmp
docker compose restart backend
```

## 문제 확인 순서

백엔드가 안 뜰 때:

```bash
cd ~/capstone/docker
docker compose ps
docker compose logs --tail=200 backend
```

DB 연결 오류가 보이면 `.env`의 `DB_*` 값과 Postgres 상태를 확인한다.

```bash
docker compose ps postgres
docker compose logs --tail=100 postgres
```

프론트에서 API 호출이 이상하면 `.env`의 `NEXT_PUBLIC_API_BASE_URL`, 백엔드의 `CORS_ALLOWED_ORIGINS`, `FRONTEND_BASE_URL`을 같이 확인한다. `NEXT_PUBLIC_API_BASE_URL`을 바꾼 뒤에는 프론트를 다시 빌드해야 함.

```bash
docker compose build frontend
docker compose up -d frontend
```

nginx 경유 구조에서는 `NEXT_PUBLIC_API_BASE_URL`이 빈 값인지 먼저 확인한다.

## Caddy

로컬 개발은 Caddy 없이 `docker-compose.yml`만 사용한다(`http://localhost`, nginx 80 공개).

도메인 배포(`gamerin.live`)는 `docker-compose.prod.yml`을 겹쳐 쓴다. Caddy가 TLS 종단·인증서 자동 발급/갱신·HTTP→HTTPS 리다이렉트를 맡고 `nginx:80`으로 넘긴다. Caddy만 80/443을 공개하고 nginx 호스트 포트는 닫힌다.

```bash
docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d
```

- DNS A 레코드 `gamerin.live` → 서버 공인 IP, 서버 방화벽에서 80/443(TCP)·443(UDP) 개방
- `SITE_ADDRESS`(기본 `gamerin.live`), `HSTS_MAX_AGE`(기본 `300`)로 조정한다. HSTS는 `300` → `86400` → `31536000` 순서로 올린다.
- 인증서는 `../data/caddy`에 저장된다. 지우면 재발급하므로 발급 한도에 걸릴 수 있다.
- nginx는 Caddy 고정 IP(`10.250.0.2`)에서 온 요청만 `X-Forwarded-Proto`·`X-Forwarded-For`를 신뢰한다. 이 IP를 바꾸면 `nginx/default.conf`도 같이 바꾼다.
- 서브넷 고정 때문에 기존 `gamerin` 네트워크가 있으면 먼저 `docker compose down`(볼륨 유지) 후 올린다.
- 서버 `.env`: `FRONTEND_BASE_URL=https://gamerin.live`, `CORS_ALLOWED_ORIGINS`에 `https://gamerin.live`, `REFRESH_COOKIE_SECURE=true`, `STREAM_TOKEN_COOKIE_SECURE=true`, `NEXT_PUBLIC_API_BASE_URL` 빈 값
- Google OAuth redirect URI: `https://gamerin.live/login/oauth2/code/google`
- `scripts/deploy.sh`는 아직 prod override를 쓰지 않는다.

## 수정 일지

- **26/07/21** 서장호

  > `.env.example`에 `R6DATA_API_KEY`, `R6DATA_API_BASE_URL`, 연결·응답 읽기 timeout 예시를 추가
  > R6Data 기본 URL은 `https://api.r6data.com`, 연결 timeout은 `3s`, 응답 읽기 timeout은 `10s`로 구성
  > `docker-compose.yml`에서 R6Data 환경변수를 백엔드 컨테이너에 전달하도록 추가
  > R6Data API 키는 프론트엔드에 노출하지 않고 백엔드 런타임에만 주입하도록 유지
  > 검증: `docker compose --env-file .env.example config --quiet`, `git diff --check` 통과

  > 요약 : Docker 배포 환경에서 R6Data API 설정을 백엔드에 안전하게 주입할 수 있도록 예시와 Compose 전달 구성을 추가
