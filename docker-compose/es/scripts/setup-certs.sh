#!/bin/bash

# ===========================================
# Elasticsearch SSL 证书生成脚本
# 文件名: setup-certs.sh
# 功能: 自动生成 Elasticsearch 集群的 SSL 证书
# ===========================================

set -e

echo "🔐 开始生成 Elasticsearch SSL 证书..."

# 检查 Docker 是否运行
if ! docker info > /dev/null 2>&1; then
    echo "❌ Docker 未运行，请先启动 Docker"
    exit 1
fi

# 创建证书目录
echo "📁 创建证书目录..."
mkdir -p certs/{ca,es01,es02,es03}

# 生成 CA 证书
echo "🏛️ 生成 CA 证书..."
docker run --rm -v $(pwd)/certs:/certs \
  docker.elastic.co/elasticsearch/elasticsearch:8.15.3 \
  /bin/bash -c "
    elasticsearch-certutil ca --out /certs/ca/ca.p12 --pass '' --silent
  "

# 生成节点证书
echo "🔑 生成节点证书..."
for node in es01 es02 es03; do
    echo "  - 生成 $node 证书..."
    docker run --rm -v $(pwd)/certs:/certs \
      docker.elastic.co/elasticsearch/elasticsearch:8.15.3 \
      /bin/bash -c "
        elasticsearch-certutil cert --ca /certs/ca/ca.p12 --ca-pass '' \
          --out /certs/$node/$node.p12 --name $node --dns $node --pass '' --silent
      "
done

# 转换证书格式
echo "🔄 转换证书格式..."
for node in es01 es02 es03; do
    echo "  - 转换 $node 证书..."
    docker run --rm -v $(pwd)/certs:/certs \
      docker.elastic.co/elasticsearch/elasticsearch:8.15.3 \
      /bin/bash -c "
        openssl pkcs12 -in /certs/$node/$node.p12 -out /certs/$node/$node.crt -clcerts -nokeys -passin pass: &&
        openssl pkcs12 -in /certs/$node/$node.p12 -out /certs/$node/$node.key -nocerts -nodes -passin pass:
      "
done

# 提取 CA 证书
echo "📜 提取 CA 证书..."
docker run --rm -v $(pwd)/certs:/certs \
  docker.elastic.co/elasticsearch/elasticsearch:8.15.3 \
  /bin/bash -c "
    openssl pkcs12 -in /certs/ca/ca.p12 -out /certs/ca/ca.crt -clcerts -nokeys -passin pass:
  "

# 设置证书权限
echo "🔒 设置证书权限..."
chmod -R 644 certs/
find certs/ -name "*.key" -exec chmod 600 {} \;

echo "✅ SSL 证书生成完成！"
echo ""
echo "📋 生成的证书文件："
echo "  - CA 证书: certs/ca/ca.crt"
echo "  - ES01 证书: certs/es01/es01.crt"
echo "  - ES01 私钥: certs/es01/es01.key"
echo "  - ES02 证书: certs/es02/es02.crt"
echo "  - ES02 私钥: certs/es02/es02.key"
echo "  - ES03 证书: certs/es03/es03.crt"
echo "  - ES03 私钥: certs/es03/es03.key"
echo ""
echo "🚀 现在可以启动 Elasticsearch 集群了！" 