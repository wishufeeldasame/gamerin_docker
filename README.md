# Gamerin Docker 운영 가이드

## 기준 경로

서버는 아래 구조로 구성

```text
/srv/gamerin
├── backend
├── frontend
├── docker
├── data
│   ├── postgres
│   ├── tmp
│   └── uploads
└── backups
```

운영 명령은 기본적으로 Docker repo에서 실행합니다.

```bash
cd /srv/gamerin/docker
```

## 구성 파일

- `docker-compose.yml`: 백엔드, 프론트엔드, Postgres 실행 정의
- `.env`: 서버에서만 관리하는 실제 환경변수 파일
- `.env.example`: `.env` 작성 기준 예시
- `Caddyfile.example`: Caddy reverse proxy 예시
- `scripts/deploy.sh`: 이미지 빌드 후 전체 서비스 기동
- `scripts/logs.sh`: 서비스 로그 확인
- `scripts/down.sh`: 전체 서비스 중지
- `scripts/backup-postgres.sh`: DB 백업
- `scripts/restore-postgres.sh`: DB 복원

`.env`는 GitHub에 올리지 않습니다.

## 현재 상태 확인

```bash
cd /srv/gamerin/docker
docker compose ps
```

컨테이너 로그를 짧게 확인하려면:

```bash
docker compose logs --tail=100 backend
docker compose logs --tail=100 frontend
docker compose logs --tail=100 postgres
```

실시간 로그를 보려면:

```bash
./scripts/logs.sh backend
./scripts/logs.sh frontend
```

종료는 `Ctrl + C`입니다. 로그 보기만 종료되고 서버는 내려가지 않습니다.

## 전체 배포

백엔드, 프론트엔드, Docker 설정을 모두 최신으로 가져온 뒤 배포합니다.

```bash
cd /srv/gamerin/backend
git pull

cd /srv/gamerin/frontend
git pull

cd /srv/gamerin/docker
git pull
./scripts/deploy.sh
```

`deploy.sh`는 아래 작업을 수행합니다.

```bash
docker compose --env-file .env build backend frontend
docker compose --env-file .env up -d
docker compose --env-file .env ps
```

## 백엔드만 배포

백엔드 코드만 바뀐 경우:

```bash
cd /srv/gamerin/backend
git pull

cd /srv/gamerin/docker
docker compose build backend
docker compose up -d backend
docker compose logs --tail=100 -f backend
```

백엔드는 `SPRING_PROFILES_ACTIVE=prod`로 실행됩니다. 서버 배포에서는 `application-local.yaml`을 사용하지 않습니다.

## 프론트엔드만 배포

프론트엔드 코드만 바뀐 경우:

```bash
cd /srv/gamerin/frontend
git pull

cd /srv/gamerin/docker
docker compose build frontend
docker compose up -d frontend
docker compose logs --tail=100 -f frontend
```

`NEXT_PUBLIC_API_BASE_URL`은 프론트 빌드 시점에 들어갑니다. `.env`에서 이 값을 바꿨다면 반드시 `docker compose build frontend`를 다시 실행해야 합니다.

## Docker 설정만 반영

`docker-compose.yml`, 스크립트, `.env.example` 같은 Docker repo 변경만 반영할 때:

```bash
cd /srv/gamerin/docker
git pull
docker compose up -d
docker compose ps
```

이미지 빌드 설정이 바뀐 경우에는 다시 빌드합니다.

```bash
docker compose build backend frontend
docker compose up -d
```

## 환경변수 수정

실제 서버 값은 `/srv/gamerin/docker/.env`에서 관리합니다.

```bash
cd /srv/gamerin/docker
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

주요 DB 변수명은 `DB_*`로 통일되어 있습니다.

```dotenv
DB_HOST=postgres
DB_PORT=5432
DB_NAME=gamerin
DB_USERNAME=gamerin
DB_PASSWORD=change-me
```

Compose는 이 값을 Postgres 컨테이너에는 `POSTGRES_*`로 변환해서 주입하고, 백엔드에는 `DB_*` 그대로 주입합니다.

## 서버 재시작

전체 서비스 재시작:

```bash
cd /srv/gamerin/docker
docker compose restart
```

특정 서비스만 재시작:

```bash
docker compose restart backend
docker compose restart frontend
docker compose restart postgres
```

## 서버 내리기

전체 컨테이너를 내립니다. DB 데이터와 업로드 파일은 유지됩니다.

```bash
cd /srv/gamerin/docker
./scripts/down.sh
```

다시 올리려면:

```bash
docker compose up -d
```

운영 서버에서 `docker compose down -v`는 사용하지 않습니다. DB volume 삭제로 이어질 수 있습니다.

## DB 백업과 복원

백업:

```bash
cd /srv/gamerin/docker
./scripts/backup-postgres.sh
```

백업 파일은 `/srv/gamerin/backups/postgres-YYYYMMDD-HHMMSS.sql` 형식으로 생성됩니다.

복원:

```bash
cd /srv/gamerin/docker
./scripts/restore-postgres.sh /srv/gamerin/backups/postgres-YYYYMMDD-HHMMSS.sql
```

복원은 현재 DB에 데이터를 다시 쓰는 작업입니다. 운영 데이터에 실행하기 전에는 반드시 최근 백업을 하나 더 만들어둡니다.

## 데이터 경로

- DB 데이터: `/srv/gamerin/data/postgres`
- 업로드 파일: `/srv/gamerin/data/uploads`
- 백엔드 임시 파일: `/srv/gamerin/data/tmp`
- DB 백업 파일: `/srv/gamerin/backups`

피드 이미지나 업로드 파일은 `/srv/gamerin/data/uploads`에 남습니다. 컨테이너를 다시 만들거나 이미지를 다시 빌드해도 이 폴더는 유지됩니다.

## 권한 문제

백엔드 컨테이너는 UID `10001` 사용자로 실행됩니다. 업로드나 임시 파일 생성에서 권한 오류가 나면 서버에서 아래를 실행합니다.

```bash
sudo chown -R 10001:10001 /srv/gamerin/data/uploads /srv/gamerin/data/tmp
docker compose restart backend
```

## 문제 확인 순서

백엔드가 안 뜰 때:

```bash
cd /srv/gamerin/docker
docker compose ps
docker compose logs --tail=200 backend
```

DB 연결 오류가 보이면 `.env`의 `DB_*` 값과 Postgres 상태를 확인합니다.

```bash
docker compose ps postgres
docker compose logs --tail=100 postgres
```

프론트에서 API 호출이 이상하면 `.env`의 `NEXT_PUBLIC_API_BASE_URL`, 백엔드의 `CORS_ALLOWED_ORIGINS`, `FRONTEND_BASE_URL`을 같이 확인합니다. `NEXT_PUBLIC_API_BASE_URL`을 바꾼 뒤에는 프론트를 다시 빌드해야 합니다.

```bash
docker compose build frontend
docker compose up -d frontend
```

## GitHub에 올릴 때

이 repo에는 운영 비밀값을 넣지 않습니다.

```bash
git status
git add .
git commit -m "Update Docker operations guide"
git push
```

커밋 전에 `.env`가 포함되지 않았는지 확인합니다.

```bash
git status --short
```
