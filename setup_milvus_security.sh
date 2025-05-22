#!/bin/bash

# deploy_milvus.sh - Milvus安全部署脚本 (Host网络模式)
set -e  # 遇到错误立即退出

echo "🚀 开始部署Milvus (Host网络模式)..."

# 1. 检查端口占用
echo "🔍 检查端口占用..."
ports=(2379 9000 9001 19530 9091)
for port in "${ports[@]}"; do
    if lsof -i :$port >/dev/null 2>&1; then
        echo "❌ 端口 $port 已被占用，请先释放该端口"
        lsof -i :$port
        exit 1
    fi
done
echo "✅ 所有必要端口都可用"

# 2. 清理旧的部署
echo "🧹 清理旧的部署..."
docker compose down -v 2>/dev/null || true

# 3. 检查必要文件
echo "📋 检查必要文件..."
required_files=("docker-compose.yml" "milvus.yaml" "secure_init.py")
for file in "${required_files[@]}"; do
    if [[ ! -f "$file" ]]; then
        echo "❌ 缺少文件: $file"
        exit 1
    fi
done
echo "✅ 所有必要文件存在"

# 4. 创建环境变量文件（如果不存在）
if [[ ! -f ".env" ]]; then
    echo "📝 创建.env文件..."
    cat > .env << EOF
DOCKER_VOLUME_DIRECTORY=./
MINIO_ACCESS_KEY=milvus-access-key
MINIO_SECRET_KEY=milvus-secret-key-with-32-characters
EOF
fi

# 5. 创建数据目录
echo "📁 创建数据目录..."
mkdir -p volumes/{etcd,minio,milvus}

# 6. 启动服务
echo "🔄 启动Milvus服务..."
docker compose up -d etcd minio

# 等待基础服务健康
echo "⏳ 等待etcd和minio启动..."
sleep 10

# 启动Milvus主服务
echo "🔄 启动Milvus主服务..."
docker compose up -d standalone

# 等待Milvus健康
echo "⏳ 等待Milvus启动..."
timeout=120
counter=0
while ! curl -f http://localhost:9091/healthz >/dev/null 2>&1 && [ $counter -lt $timeout ]; do
    echo "等待Milvus健康检查... ($counter/$timeout)"
    sleep 2
    counter=$((counter + 2))
done

if [ $counter -ge $timeout ]; then
    echo "❌ Milvus启动超时"
    echo "查看日志:"
    docker compose logs standalone
    exit 1
fi

echo "✅ Milvus启动成功"

# 7. 运行安全初始化
echo "🔒 运行安全初始化..."
docker compose up security-init

# 8. 检查状态
echo "📊 检查部署状态..."
docker compose ps

# 9. 显示连接信息
echo ""
echo "🎉 部署完成!"
echo "=================================="
echo "Milvus连接信息:"
echo "  - 主机: localhost"
echo "  - 端口: 19530"
echo "  - Web UI: http://localhost:9091"
echo "  - MinIO控制台: http://localhost:9001"
echo ""
echo "认证信息:"
if [[ -f ".milvus_app_credentials" ]]; then
    cat .milvus_app_credentials
else
    echo "  - 默认用户: root"
    echo "  - 默认密码: Milvus"
    echo "  ⚠️  请立即修改默认密码!"
fi
echo "=================================="

# 10. 测试连接
echo "🧪 测试连接..."
if command -v python3 &> /dev/null; then
    python3 -c "
from pymilvus import MilvusClient
try:
    client = MilvusClient(uri='http://localhost:19530', token='root:Milvus')
    print('✅ 连接测试成功')
except Exception as e:
    print(f'❌ 连接测试失败: {e}')
" 2>/dev/null || echo "⚠️  Python pymilvus未安装，跳过连接测试"
else
    echo "⚠️  Python未安装，跳过连接测试"
fi

echo ""
echo "📝 注意事项 (Host网络模式):"
echo "  ⚠️  所有服务直接使用主机端口，请确保防火墙配置正确"
echo "  ⚠️  在生产环境中建议使用防火墙限制端口访问"
echo ""
echo "📝 下一步:"
echo "  1. 修改默认密码"
echo "  2. 创建应用用户" 
echo "  3. 配置防火墙规则"