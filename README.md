# Gamerin Docker 

## 기준 경로

```text
~/capstone
├── backend
├── frontend
├── docker
│   └── nginx
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

배포 후 접속 주소는 nginx 기준으로 하나만 사용합니다.

```text
집 내부: http://서버_내부_IP
외부 팀원: http://서버_공인_IP
```

프론트는 `/api/...` 상대경로로 백엔드를 호출하고, nginx가 `/api` 요청을 백엔드로 전달합니다.

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

nginx 구조에서는 일반적으로 아래처럼 둡니다.

```dotenv
NGINX_BIND=0.0.0.0
NGINX_PORT=80
NEXT_PUBLIC_API_BASE_URL=
CORS_ALLOWED_ORIGINS=http://공인IP,http://내부IP
FRONTEND_BASE_URL=http://공인IP
REFRESH_COOKIE_SECURE=false
```

`NEXT_PUBLIC_API_BASE_URL`은 빈 값으로 둡니다. 그래야 프론트가 `http://공인IP:8080/api/...` 같은 절대주소가 아니라 `/api/...` 상대경로로 호출합니다.

공유기 포트포워딩은 외부 80번을 서버 노트북 내부 IP의 80번으로 연결합니다.

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

현재 개발 서버 구성에서는 Caddy를 사용하지 않고 nginx 컨테이너를 사용한다. 도메인과 HTTPS를 붙일 때만 Caddy 또는 호스트 nginx 같은 별도 reverse proxy 구성을 검토한다.
