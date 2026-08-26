# platform/

Mọi thứ chạy trên cluster, quản lý bằng Argo CD.

| Thư mục | Nội dung |
|---|---|
| `helmfile/` | Bootstrap Argo CD. Chạy đúng một lần bằng tay. |
| `argocd/` | `app-of-apps.yaml` -> `apps/*.yaml`. Từ đây trở đi mọi thay đổi qua Git. |
| `argocd/appsets/` | ApplicationSet sinh root cho nhiều cluster (`clusters/*/config.yaml`). |
| `gitlab/` | GitLab CE Omnibus. |
| `gitlab-runner/` | Secret bootstrap; chart cài từ https://charts.gitlab.io qua Argo. |

## Sync waves
```
-1  storage-local-path   StorageClass mặc định — phải có trước mọi PVC
 0  gitlab               cần PVC
 1  gitlab-runner        cần GitLab đang chạy + token lấy từ UI
```

## Vì sao không có ingress controller
Cluster chỉ truy cập được trong tailnet. Dịch vụ expose bằng NodePort, và nhờ
Cilium `kubeProxyReplacement`, NodePort nghe trên mọi node kể cả node không
chạy pod. Không có ingress thì cũng không cần cert-manager — trước đây hai
thành phần đó tồn tại chủ yếu để phục vụ nhau.

## Secret
Không có sealed-secrets. Mỗi thành phần cần secret có `secrets/bootstrap.sh` +
`*.env.example`; giá trị thật nằm trong `*.env` đã gitignore. Đơn giản, và
điểm quan trọng: thiếu secret thì pod dừng ở `CreateContainerConfigError` chứ
không rơi về một giá trị mặc định nào.
