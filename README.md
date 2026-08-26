# K8sSecDaP-deploy

GitOps manifests cho cluster bare-metal 2-3 node (Ubuntu 24.04, mọi traffic đi
qua Tailscale). Cluster do `K8sSecDaP-infra` dựng bằng Ansible; repo này lo
mọi thứ chạy *trên* cluster đó.

## Layout
- `platform/helmfile/` — bootstrap duy nhất: cài Argo CD.
- `platform/argocd/` — app-of-apps + một Application cho mỗi thành phần.
- `platform/gitlab/` — GitLab CE (Omnibus, một pod) + Service NodePort.
- `platform/gitlab-runner/` — bootstrap secret cho GitLab Runner (chart cài qua Argo).

## Thứ tự dựng
```
1. Cluster Ready + Cilium Ready        (K8sSecDaP-infra: make sync && make setup)
2. helmfile -f platform/helmfile/helmfile-bootstrap.yaml apply
3. platform/gitlab/secrets/bootstrap.sh            # cần gitlab.env
4. kubectl apply -f platform/argocd/app-of-apps.yaml
   -> wave -1: local-path-provisioner
   -> wave  0: GitLab            (6-12 phút cho lần reconfigure đầu)
5. Tạo instance runner trong GitLab UI, lấy token glrt-...
6. platform/gitlab-runner/secrets/bootstrap.sh     # cần runner.env
   -> wave  1: GitLab Runner tự sync
```

## Đã bỏ (2026-08-24)
Stack SOC và toàn bộ platform cũ: Tekton, Traefik, cert-manager, sealed-secrets,
Cloudflare tunnel, Kyverno, Prometheus/Grafana, Loki, uptime-kuma, metrics-server,
CoreDNS override, Calico. CI chuyển sang GitLab CI (`ci-templates/`), CNI chuyển
sang Cilium (`K8sSecDaP-infra`, role `cni_cilium`).

## Argo CD repo credentials
`app-of-apps.yaml` và `apps/gitlab.yaml` trỏ tới repo này bằng URL SSH, nên Argo
CD cần một deploy key đã đăng ký:
```
argocd repo add git@github.com:john-naeder/K8sSecDaP-deploy.git --ssh-private-key-path <key>
```
