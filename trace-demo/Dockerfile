# 使用官方 Go 镜像（指定版本）
FROM golang:1.24.3-alpine AS builder

# 设置工作目录
WORKDIR /app

# 复制 go.mod 和 go.sum（先复制以利用 Docker 缓存）
COPY go.mod go.sum ./
RUN go mod download

# 复制源代码
COPY . .

# 构建 Linux 版本
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/gateway /app/api-gateway
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/backservice1 /app/backend-service/back1.go
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /app/backservice2 /app/backend-service/back2.go


# 构建 macOS 版本
RUN CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o /app/gateway-mac /app/api-gateway
RUN CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o /app/backservice1-mac /app/backend-service/back1.go
RUN CGO_ENABLED=0 GOOS=darwin GOARCH=amd64 go build -o /app/backservice2-mac /app/backend-service/back2.go

RUN #CGO_ENABLED=0 GOOS=darwin GOARCH=arm64 go build -o /app/myapp-macos-arm64

# 最终阶段（仅提取二进制文件）
FROM alpine:latest
COPY --from=builder /app/* /