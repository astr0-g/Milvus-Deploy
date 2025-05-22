#!/bin/bash
# setup_milvus_security.sh

echo "🚀 启动Milvus服务..."
docker compose up -d standalone

echo "⏳ 等待Milvus服务健康..."
# 等待健康检查通过
while ! docker compose ps standalone | grep -q "healthy"; do
    echo "等待中..."
    sleep 5
done

echo "✅ Milvus服务已就绪"

echo "📦 安装pymilvus..."
pip install pymilvus==2.5.2

echo "🔒 执行安全初始化..."
python secure_init.py

echo "🎉 设置完成！"
echo "请查看 .milvus_app_credentials 文件获取应用连接信息"