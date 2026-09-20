# minisvc

内部小 Go HTTP 服务（/healthz /readyz /version /v1/ping）。

当前交付很乱：
- 本地：`./scripts/local_build.sh` 或 `./build.sh`（两个入口不一致）
- 镜像：根目录 `Dockerfile`（单阶段，迁移文件是否进镜像大家说法不一）
- 编排：`docker-compose.yml`（配置挂载路径和文档对不上）

还没有统一的 test → build → image → compose 冒烟入口。业务代码先别大动。
