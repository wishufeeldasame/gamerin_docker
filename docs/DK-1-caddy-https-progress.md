# DK-1 gamerin.live HTTPS 배포(Caddy) 진행 상황

이슈: https://github.com/wishufeeldasame/gamerin_docker/issues/1
기준일: 2026-10-26 · 범위: **설정 작성·격리 검증** 완료, **실서버 검증**은 배포 당일(이슈 #3)

## 전제
- 각자 PC 테스트는 기존처럼 `docker-compose.yml`만 사용한다(`http://localhost`).
- 선행: FE-1 PR 3(Next의 HSTS 헤더 삭제) + 프론트 이미지 리빌드. **상태 확인 필요.** Caddy가 `defer`로 HSTS를 덮어쓰므로 선행 전에도 최종 값은 Caddy 값이다.

## 변경 내용
| 파일 | 내용 |
|---|---|
| `Caddyfile` (신규) | `{$SITE_ADDRESS:gamerin.live}` → `nginx:80`. HSTS `max-age={$HSTS_MAX_AGE:300}` + `defer`. includeSubDomains/preload 없음. SSE는 Caddy가 스트리밍 응답으로 보고 즉시 flush |
| `docker-compose.prod.yml` (신규) | 배포 전용 override. caddy(80/443/443udp, 인증서 `../data/caddy:/data`, 고정 IP `10.250.0.2`), nginx `ports: !reset []`, 서브넷 `10.250.0.0/24` + 동적 할당 `ip_range 10.250.0.128/25` |
| `nginx/default.conf` | `geo`로 `10.250.0.2`만 신뢰. Proto는 Caddy가 `https`라고 보낸 경우만 `https`(Port 443), 그 외는 nginx 자신의 값. `set_real_ip_from`+`real_ip_header X-Forwarded-For`로 클라이언트 IP 복원. `X-Forwarded-For`/`X-Real-IP`는 `$remote_addr`로 덮어쓰고 `Forwarded` 제거. 헤더 블록을 `location /`, `location = /payments/result`에도 반복(상속 규칙) |
| `.env.example` | `SITE_ADDRESS`, `HSTS_MAX_AGE` 추가. SSE 쿠키는 main의 `STREAM_TOKEN_COOKIE_SECURE`(compose 기본 `true`)를 그대로 쓴다 |
| `.gitignore` | `Caddyfile` 무시 규칙 제거 |
| `README.md` | Caddy 절을 prod override 사용법·DNS·서버 `.env` 값으로 교체 |

설계 메모
- `ip_range`가 없으면 Docker는 서브넷의 `.2`부터 순서대로 준다. caddy는 nginx에 의존해 가장 늦게 생성되므로 다른 컨테이너가 `.2`를 먼저 가져가 기동이 실패한다(격리 네트워크에서 첫 컨테이너가 `.2`를 받는 것 확인).
- Caddy는 `trusted_proxies`가 없으면 들어온 `X-Forwarded-*`를 버리고 실제 접속 IP·`https`를 보낸다. nginx는 이 값만 신뢰한다.
- 백엔드는 `application-prod.yaml`의 `forward-headers-strategy: framework`로 `X-Forwarded-*`를 해석하고, `RateLimitFilter`는 `X-Forwarded-For` 첫 값을 쓴다. nginx가 단일 값으로 덮어쓰므로 위조로 우회할 수 없다.
- 기존 `Caddyfile.example`(호스트 직설치·서브도메인 예시)은 그대로 둠.

## 검증 결과(2026-10-26, 로컬 OrbStack, 임시 컨테이너)
- `docker compose --env-file .env.example config --quiet`: 통과. 병합 결과 nginx `0.0.0.0:80` 공개, caddy 없음
- `docker compose --env-file .env.example -f docker-compose.yml -f docker-compose.prod.yml config --quiet`: 통과. nginx `ports` 없음, caddy 80/443/443udp, 고정 IP `10.250.0.2`, `ip_range` 반영
- `nginx -t`(nginx:1.27-alpine, upstream은 `--add-host`): 통과
- `caddy validate`(caddy v2.11.7): `Valid configuration`, `caddy fmt` 차이 없음
- 격리 네트워크(`10.250.0.0/24`, Caddy `SITE_ADDRESS=localhost` 내부 CA, 스텁 백엔드/프론트):
  - nginx 직접 + 위조 헤더(`X-Forwarded-Proto: https`, `X-Forwarded-For`, `X-Forwarded-Port`, `Forwarded`, `X-Real-IP`): `/api/`, `/`, `/payments/result` 모두 `proto=http port=80`, XFF/X-Real-IP=실제 접속 IP, `Forwarded` 없음
  - Caddy 경유 + 같은 위조 헤더: 세 경로 모두 `proto=https port=443`, XFF/X-Real-IP=실제 클라이언트 IP, `Host`/`X-Forwarded-Host` 유지
  - HSTS: 업스트림이 `max-age=63072000`을 내도 최종 `max-age=300`
  - `http://` → `308` `https://`
  - nginx access log에 실제 클라이언트 IP 기록
  - 업로드(Caddy 경유): profile-images 5MB `200`, 7MB `413`
  - post_upload rate limit: 클라이언트 A 8회 연속 → 6회 `200` 후 `503`, 직후 클라이언트 B `200`(IP별 동작)
  - SSE(Caddy 경유): 1.5초 간격 이벤트가 생성 즉시 수신
- 시험 후 임시 컨테이너·네트워크 정리

## 남은 작업 (배포 당일, 이슈 #3)
- [ ] 인스턴스: 80/443(TCP)·443(UDP) 개방(VCN Security List/NSG + OS 방화벽), Reserved Public IP, DNS A 레코드 `gamerin.live`
- [ ] CPU 아키텍처(x86/ARM) 확인, 이미지 빌드 방식 결정
- [ ] 서버 `.env`: `FRONTEND_BASE_URL=https://gamerin.live`, `CORS_ALLOWED_ORIGINS`에 도메인, `REFRESH_COOKIE_SECURE=true`, `STREAM_TOKEN_COOKIE_SECURE=true`, `NEXT_PUBLIC_API_BASE_URL` 빈 값
- [ ] Google OAuth 콘솔 redirect URI: `https://gamerin.live/login/oauth2/code/google`
- [ ] 배포: `docker compose --env-file .env -f docker-compose.yml -f docker-compose.prod.yml up -d` (기존 `gamerin` 네트워크가 있으면 먼저 down)
- [ ] `scripts/deploy.sh`가 prod override를 쓰지 않음 → 배포 방식 결정 후 수정
- [ ] 완료 조건 E2E: 인증서 발급, 로그인·새로고침 유지·업로드·SSE, 리다이렉트와 HSTS, 쿠키 `Secure` 2종, OAuth `redirect_uri`, 비밀번호 재설정 링크, IP별 rate limit
- [ ] HSTS 단계 상향: 300 → 86400 → 31536000 (`HSTS_MAX_AGE`)

## 알아둘 점 / 확인 필요
- IPv6 클라이언트는 docker-proxy를 거치며 접속 IP가 게이트웨이로 보일 수 있다. 리눅스 서버에서 확인 필요.
- postgres의 `127.0.0.1` 포트 바인딩은 loopback 한정. 배포 시 제거 여부는 별도 결정.
