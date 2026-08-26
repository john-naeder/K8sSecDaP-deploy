#!/usr/bin/env bash
# =============================================================================
# Tạo Secret cho MinIO và cho Velero từ cùng một bộ giá trị.
#
# Velero cần credential ở ĐỊNH DẠNG KHÁC với MinIO: MinIO đọc biến môi trường
# MINIO_ROOT_*, còn Velero đọc một file kiểu ~/.aws/credentials. Cùng giá trị,
# hai hình dạng — nên script này tạo cả hai để chúng không lệch nhau.
# =============================================================================
set -euo pipefail
cd "$(dirname "$0")"

[[ -f minio.env ]] || { echo "thiếu minio.env — copy từ minio.env.example"; exit 1; }
# shellcheck source=/dev/null
set -a; source minio.env; set +a

: "${MINIO_ROOT_USER:?rỗng}"
: "${MINIO_ROOT_PASSWORD:?rỗng}"
(( ${#MINIO_ROOT_PASSWORD} >= 8 )) || { echo "MinIO từ chối mật khẩu ngắn hơn 8 ký tự"; exit 1; }

kubectl create namespace velero --dry-run=client -o yaml | kubectl apply -f -

kubectl -n velero create secret generic minio-creds \
  --from-literal=MINIO_ROOT_USER="$MINIO_ROOT_USER" \
  --from-literal=MINIO_ROOT_PASSWORD="$MINIO_ROOT_PASSWORD" \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl -n velero create secret generic velero-s3-creds \
  --from-literal=cloud="[default]
aws_access_key_id=${MINIO_ROOT_USER}
aws_secret_access_key=${MINIO_ROOT_PASSWORD}" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "minio-creds và velero-s3-creds đã sẵn sàng."
