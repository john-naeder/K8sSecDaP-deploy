#!/usr/bin/env bash
# =============================================================================
# Tạo Secret gitlab-runner-secret từ runner.env.
#
# Chạy SAU khi GitLab đã lên và bạn đã tạo instance runner trong UI.
# Chart gitlab-runner đọc key runner-token; key runner-registration-token để
# rỗng vì luồng registration cũ đã bị bỏ từ GitLab 16.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

[[ -f runner.env ]] || { echo "thiếu runner.env — copy từ runner.env.example"; exit 1; }
# shellcheck source=/dev/null
set -a; source runner.env; set +a

: "${runner_token:?runner_token rỗng trong runner.env}"
[[ "${runner_token}" == glrt-* ]] || {
  echo "runner_token không bắt đầu bằng 'glrt-'. Nhiều khả năng bạn đang" >&2
  echo "dùng registration token cũ; hãy tạo instance runner mới." >&2
  exit 1
}

kubectl create namespace gitlab-runner --dry-run=client -o yaml | kubectl apply -f -
kubectl -n gitlab-runner create secret generic gitlab-runner-secret \
  --from-literal=runner-token="${runner_token}" \
  --from-literal=runner-registration-token="" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "gitlab-runner-secret đã sẵn sàng."
