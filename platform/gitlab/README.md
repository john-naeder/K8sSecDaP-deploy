# GitLab CE — Omnibus một pod

## Vì sao Omnibus chứ không phải chart cloud-native
Chart `gitlab/gitlab` bản đã cắt (tắt registry, MinIO, Prometheus, Grafana,
Pages, cert-manager, 1 replica webservice) vẫn cần khoảng **6.3GB**, và cần
chừng đó trên *một* node. Worker chỉ có 7GB tổng, sau kubelet + cilium-agent
còn khoảng 5.7GB. Phần thiếu sẽ phải tràn sang master, tức đặt Gitaly hoặc
Puma cạnh etcd — cách nhanh nhất để control plane bắt đầu timeout.

Omnibus gói tất cả vào một container, request 3GB / limit 6GB.

Đánh đổi phải chấp nhận: không HA, upgrade là monolithic, không scale riêng
từng thành phần, và một lần restart là toàn bộ GitLab down.

## Truy cập
| | |
|---|---|
| Web | http://100.80.0.1:30080 |
| Git SSH | `ssh://git@100.80.0.1:30022/<group>/<project>.git` |
| Tài khoản đầu | `root` / giá trị `root_password` trong `secrets/gitlab.env` |

NodePort nghe trên **mọi** node, nên IP nào trong tailnet cũng dùng được; địa
chỉ trên chỉ là địa chỉ đã ghi vào `external_url`.

## Kiểm tra TRƯỚC khi sync
```bash
# 36Gi PVC (config 1 + logs 5 + data 30) sẽ nằm trên đĩa của một node.
ssh <user>@100.80.0.2 df -h /opt /var
```
Không đủ chỗ thì sửa `volumeClaimTemplates` trong `statefulset.yaml` — sửa
trước khi PVC được tạo, vì local-path không cho resize.

## Lần khởi động đầu
`reconfigure` + migrate DB thường 6-12 phút. `startupProbe` cho 20 phút.
Theo dõi:
```bash
kubectl -n gitlab logs -f sts/gitlab | grep -Ei 'reconfigure|migrat|error'
```
Pod đứng ở `CreateContainerConfigError` nghĩa là chưa chạy `secrets/bootstrap.sh`.

## Đưa GitLab sang node khác
Đây là chỗ dễ mất dữ liệu nhất, nên đọc kỹ.

PVC do local-path cấp là thư mục trên đĩa **một node cụ thể**, và PV mang
`nodeAffinity` trỏ đúng node đó. Nghĩa là pod bị ghim theo *dữ liệu*, không
phải theo `nodeSelector`. `kubectl cordon` node cũ rồi xoá pod sẽ **không**
đưa GitLab sang node mới — pod sẽ đứng `Pending`, vì PVC không đi theo.

Muốn chuyển thật thì phải chép dữ liệu:
```bash
kubectl -n gitlab scale sts/gitlab --replicas=0
# trên node cũ, đường dẫn dạng /opt/local-path-provisioner/pvc-<uuid>_gitlab_data-gitlab-0
rsync -aHAX --numeric-ids /opt/local-path-provisioner/<pvc-dir>/ \
      <user>@<node-mới>:/opt/local-path-provisioner/<pvc-dir>/
# sửa nodeAffinity của PV sang node mới, rồi:
kubectl -n gitlab scale sts/gitlab --replicas=1
```
Nếu chấp nhận mất sạch (chưa có repo nào quan trọng) thì nhanh hơn nhiều: xoá
PVC rồi để Argo tạo lại.

Cách bền vững hơn là bỏ local-path và dùng một CSI có replication — nhưng cái
đó cần đĩa dự phòng và RAM mà cluster này chưa có.

## Đã tắt những gì trong Omnibus
`prometheus_monitoring`, `alertmanager`, `grafana`, `registry`, `mattermost`,
`gitlab_kas`, `gitlab_pages`. Riêng bộ Prometheus + 4 exporter chiếm khoảng
500MB và hiện không có ai tiêu thụ metric đó.

Cần container registry thì bật `registry['enable'] = true`, nhưng nhớ là nó
cần thêm dung lượng đĩa và một cổng nữa.
