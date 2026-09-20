# minisvc

内部小 Go HTTP 服务（`/healthz` `/readyz` `/version` `/v1/ping`）。

## 依赖

- Go 1.22+（仅本地 `make test/build` 需要）
- Docker + Docker Compose v2

## 一条命令交付（test → 镜像 → compose → 冒烟）

```sh
make deliver
```

等价于：清理旧栈 → `go test` → 多阶段构建镜像 → `compose up` → 健康/就绪/版本/ping
冒烟；任何一步失败都以非零退出，并打印容器状态与日志。成功后服务在
`http://127.0.0.1:8080`，版本信息见 `curl :8080/version`（commit 由 ldflags 注入）。

停止：`make down`（数据卷保留）。

## 常用入口

| 命令 | 作用 |
| --- | --- |
| `make test` | 单元测试（`-race`） |
| `make build` | 带版本信息的本地二进制 `bin/minisvc` |
| `make image` | 多阶段镜像（最终层只有二进制 + `/migrations` + `/etc/minisvc/app.yaml`） |
| `make up` / `make smoke` | 发布态 compose / 冒烟 |
| `make up-dev` | 开发态：bind-mount 本地 `configs/`、`migrations/`，数据写 `./data` |

## 失败时看哪

- `make ps`：容器状态（`unhealthy` 会导致 `make smoke`/`make deliver` 失败退出）
- `make logs`：服务日志（配置/迁移路径错误在这里）
- 冒烟细节：`scripts/smoke.sh`；交付编排：`scripts/deliver.sh`
- 清理重来：`make clean`
