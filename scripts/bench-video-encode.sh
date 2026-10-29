#!/usr/bin/env bash
# 게시물 영상 재인코딩 성능을 백엔드 이미지와 같은 FFmpeg로 측정한다.
# 실서버(OCI A1 2 OCPU)와 로컬 근사에서 같은 명령으로 돌려 preset·처리 제한 시간을 정하는 용도다.
#
# 사용: scripts/bench-video-encode.sh [--cpus N | --cpuset 0,1] [--memory SIZE] [--image IMAGE] [--presets "veryfast faster"] [영상 파일...]
# 영상 파일을 주지 않으면 120초 1080p60 합성 영상(가로·세로)을 만들어 쓴다.
# 코어가 많은 기기에서 서버를 흉내 낼 때는 --cpuset을 쓴다. --cpus는 사용 시간만 제한해 x264가 보이는 코어 수만큼
# 스레드를 만들고 서로 막혀 실제보다 크게 느려진다.
set -euo pipefail

CPUS=2
CPUSET=
MEMORY=2g
IMAGE=gamerin-backend:latest
PRESETS="veryfast faster fast"
DURATION=120
INPUTS=()

while [ $# -gt 0 ]; do
  case "$1" in
    --cpus) CPUS="$2"; shift 2 ;;
    --cpuset) CPUSET="$2"; shift 2 ;;
    --memory) MEMORY="$2"; shift 2 ;;
    --image) IMAGE="$2"; shift 2 ;;
    --presets) PRESETS="$2"; shift 2 ;;
    --duration) DURATION="$2"; shift 2 ;;
    -h|--help) sed -n 2,8p "$0"; exit 0 ;;
    *) INPUTS+=("$1"); shift ;;
  esac
done

if [ -n "$CPUSET" ]; then LIMIT_ARGS=(--cpuset-cpus="$CPUSET"); LIMIT_DESC="--cpuset-cpus=$CPUSET"; else LIMIT_ARGS=(--cpus="$CPUS"); LIMIT_DESC="--cpus=$CPUS"; fi

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/gamerin-bench.XXXXXX")"
trap 'rm -rf "$WORK_DIR"' EXIT

run_ffmpeg() {
  # 측정 대상만 CPU·메모리를 제한한다. 합성 영상 생성은 제한 없이 만든다.
  docker run --rm --user root --entrypoint sh -v "$WORK_DIR:/work" "$@"
}

if [ ${#INPUTS[@]} -eq 0 ]; then
  echo "합성 영상 생성 중 (${DURATION}초, 1080p60, 움직임 많은 패턴 + 노이즈, 약 20Mbps)..." >&2
  for spec in "landscape:1920x1080" "portrait:1080x1920"; do
    name="${spec%%:*}"; size="${spec#*:}"
    run_ffmpeg "$IMAGE" -c "ffmpeg -hide_banner -loglevel error -y \
      -f lavfi -i testsrc2=size=${size}:rate=60:duration=${DURATION} \
      -f lavfi -i sine=frequency=440:duration=${DURATION} \
      -vf noise=alls=12:allf=t -c:v libx264 -preset ultrafast -b:v 20M -maxrate 20M -bufsize 40M \
      -c:a aac -b:a 128k /work/${name}.mp4"
  done
  INPUTS=("$WORK_DIR/landscape.mp4" "$WORK_DIR/portrait.mp4")
else
  for i in "${!INPUTS[@]}"; do
    # 확장자는 파일 이름에서만 구한다(없으면 붙이지 않음). FFmpeg는 내용으로 형식을 판별한다.
    name="$(basename "${INPUTS[$i]}")"
    ext=""
    case "$name" in *.*) ext=".${name##*.}" ;; esac
    cp "${INPUTS[$i]}" "$WORK_DIR/input-$i$ext"
    INPUTS[$i]="$WORK_DIR/input-$i$ext"
  done
fi

printf '| 입력 | 등급 | preset | 결과 해상도 | fps | 영상 kbps | 크기 MB | 처리 초 | 배속 |\n'
printf '|---|---|---|---|---|---|---|---|---|\n'
for input in "${INPUTS[@]}"; do
  base="$(basename "$input")"
  for tier in HD:720:4M:8M FHD:1080:8M:16M; do
    IFS=: read -r tier_name short maxrate bufsize <<< "$tier"
    # 짧은 변 기준으로 줄이고 원본보다 키우지 않는다(세로 영상도 같은 규칙).
    # 백엔드 VideoOptimizationService와 같은 식(짧은 변도 짝수로 내림).
    scale="scale=w='if(gt(iw,ih),-2,trunc(min(${short},iw)/2)*2)':h='if(gt(iw,ih),trunc(min(${short},ih)/2)*2,-2)'"
    for preset in $PRESETS; do
      result="$(run_ffmpeg "${LIMIT_ARGS[@]}" --memory="$MEMORY" "$IMAGE" -c "
        in=/work/$base; out=/work/out.mp4
        dur=\$(ffprobe -v error -show_entries format=duration -of default=nw=1:nk=1 \"\$in\")
        start=\$(date +%s.%N)
        ffmpeg -hide_banner -loglevel error -y -i \"\$in\" -map 0:v:0 -map '0:a:0?' \
          -vf \"$scale\" -fpsmax 60 -c:v libx264 -preset $preset -crf 23 -maxrate $maxrate -bufsize $bufsize \
          -pix_fmt yuv420p -c:a aac -b:a 128k -movflags +faststart -map_metadata -1 -f mp4 \"\$out\" || exit 1
        end=\$(date +%s.%N)
        info=\$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height,avg_frame_rate,bit_rate -of csv=p=0 \"\$out\")
        size=\$(stat -c %s \"\$out\")
        echo \"\$dur,\$start,\$end,\$size,\$info\"
        rm -f \"\$out\"")" || { printf '| %s | %s | %s | 실패 | | | | | |\n' "$base" "$tier_name" "$preset"; continue; }
      echo "$result" | awk -F, -v input="$base" -v tier="$tier_name" -v preset="$preset" '{
        secs = $3 - $2; split($7, fr, "/"); fps = (fr[2] > 0) ? fr[1] / fr[2] : fr[1];
        printf "| %s | %s | %s | %sx%s | %.0f | %.0f | %.1f | %.1f | %.2fx |\n",
          input, tier, preset, $5, $6, fps, $8 / 1000, $4 / 1048576, secs, $1 / secs
      }'
    done
  done
done
echo "조건: $LIMIT_DESC --memory=$MEMORY image=$IMAGE ($(docker info --format '{{.Architecture}}'))" >&2
