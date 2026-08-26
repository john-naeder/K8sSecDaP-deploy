#!/usr/bin/env bash
# =============================================================================
# Tạo Secret gitlab-secrets từ gitlab.env (file này KHÔNG nằm trong Git).
#
# Phải chạy TRƯỚC khi Argo CD sync app gitlab. Nếu chưa có Secret, pod sẽ
# đứng ở CreateContainerConfigError — đó là hành vi đúng: thà không khởi
# động còn hơn khởi động với một mật khẩu mặc định nào đó.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

[[ -f gitlab.env ]] || { echo "thiếu gitlab.env — copy từ gitlab.env.example"; exit 1; }
# shellcheck source=/dev/null
set -a; source gitlab.env; set +a

: "${root_password:?root_password rỗng trong gitlab.env}"
if (( ${#root_password} < 12 )); then
  echo "root_password ngắn hơn 12 ký tự — GitLab sẽ lặng lẽ bỏ qua nó." >&2
  exit 1
fi

kubectl create namespace gitlab --dry-run=client -o yaml | kubectl apply -f -
kubectl -n gitlab create secret generic gitlab-secrets \
  --from-literal=root_password="${root_password}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "gitlab-secrets đã sẵn sàng trong namespace gitlab."
