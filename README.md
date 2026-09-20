# minisvc

内部小 Go HTTP 服务（`/healthz` `/readyz` `/version` `/v1/ping`）。

## 依赖

- Go 1.22+（仅本地 `make test` / `make build` 需要）
- Docker + Compose 插件（`make image` / `make release` 需要）

## 一条命令：test → 镜像 → compose → 冒烟

```sh
make release
```

任何一步失败都会非零退出。版本/提交/构建时间通过 ldflags 打进二进制，
冒烟会校验 `/version` 与本次构建一致。

## 常用入口

- `make test` — 跑单测
- `make build` — 本地构建到 `bin/minisvc`（带版本信息）
- `make image` — 构建多阶段镜像（只含二进制 + `migrations/` + 默认配置）
- `make up` / `make down` — 拉起 / 销毁 compose 服务
- `make smoke` — 对运行中的服务冒烟

## 失败时看哪

- 冒烟失败：`docker compose logs minisvc`
- 清理重来：`make clean`（会删数据卷）
- 本地直接跑：`go run ./cmd/minisvc -config configs/app.yaml`
