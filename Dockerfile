# ============================================
# Godot 4.4 服务端 Dockerfile — Sealos 部署
# 多阶段构建: 导出阶段 + 运行阶段
# ============================================

# ---------- 阶段 1: 导出 Godot 服务端二进制 ----------
FROM --platform=$BUILDPLATFORM godotengine/godot:4.4 AS exporter

ARG TARGETARCH=amd64

WORKDIR /project

# 复制项目文件
COPY . .

# 导出服务端 (headless Linux)
# 使用 Godot CLI 导出预设 "Linux Server" (preset.1)
RUN mkdir -p build/server && \
    if [ "$TARGETARCH" = "arm64" ]; then \
        echo "注意: Godot 4.4 官方镜像目前仅支持 amd64, ARM64 需要交叉编译或使用自定义构建"; \
    fi && \
    godot --headless --export-release "Linux Server" build/server/multiplayer_server.x86_64

# ---------- 阶段 2: 运行时 ----------
FROM ubuntu:22.04 AS runtime

LABEL org.opencontainers.image.title="Multiplayer Game Server"
LABEL org.opencontainers.image.description="Godot 4.4 多人联机游戏服务端"
LABEL org.opencontainers.image.version="0.1.0"

# 安装运行时依赖
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        libfontconfig1 \
        libfreetype6 \
        libpng16-16 \
        && rm -rf /var/lib/apt/lists/*

# 创建非 root 用户
RUN useradd -m -s /bin/bash godot && \
    mkdir -p /app && \
    chown -R godot:godot /app

WORKDIR /app

# 从导出阶段复制二进制文件
COPY --from=exporter /project/build/server/multiplayer_server.x86_64 /app/server

# 复制游戏资源 (.pck 文件如果 embed_pck=false 时需要)
# COPY --from=exporter /project/build/server/*.pck /app/

RUN chmod +x /app/server && chown -R godot:godot /app

# 切换到非 root 用户
USER godot

# 暴露端口
# 12345 = ENet UDP 游戏端口
# 12346 = HTTP 健康检查端口 (Sealos 探针)
EXPOSE 12345/udp
EXPOSE 12346/tcp

# 健康检查 — Sealos 使用此端点判断服务是否存活
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:12346/health || exit 1

# 启动服务端 (headless + 服务端场景)
ENTRYPOINT ["/app/server"]
CMD ["--headless", "--server", "--main-pack", "res://scenes/server.tscn"]
