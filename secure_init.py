#!/usr/bin/env python3
"""
Milvus安全初始化脚本 - 立即修改默认密码
"""

import time
import secrets
import string
from pymilvus import connections, utility
import os

def generate_secure_password(length=16):
    """生成安全密码"""
    alphabet = string.ascii_letters + string.digits + "!@#$%^&*"
    password = ''.join(secrets.choice(alphabet) for i in range(length))
    return password

def secure_milvus_setup():
    """安全设置Milvus"""
    print("🔒 开始Milvus安全初始化...")
    
    # 从环境变量获取连接信息
    host = os.environ.get("MILVUS_HOST", "localhost")
    port = int(os.environ.get("MILVUS_PORT", "19530"))
    
    # 等待服务启动
    max_retries = 30
    for i in range(max_retries):
        try:
            connections.connect(
                alias="default",
                host=host,
                port=port,
                user="root",
                password="Milvus"  # 使用默认密码连接
            )
            print(f"✅ 连接到Milvus成功 ({host}:{port})")
            break
        except Exception as e:
            print(f"⏳ 等待Milvus启动... ({i+1}/{max_retries}) - {str(e)[:50]}")
            time.sleep(2)
            if i == max_retries - 1:
                raise Exception(f"无法连接到Milvus服务: {e}")
    
    try:
        # 1. 立即修改root密码
        new_root_password = generate_secure_password(20)
        print("🔐 正在修改root密码...")
        utility.reset_password("root", "Milvus", new_root_password, using='default')
        print("✅ Root密码已修改为安全密码")
        
        # 保存新密码到文件（仅本次运行）
        with open('.milvus_root_password', 'w') as f:
            f.write(new_root_password)
        print("📝 新密码已保存到 .milvus_root_password 文件")
        
        # 重新连接使用新密码
        connections.disconnect("default")
        connections.connect(
            alias="default",
            host="localhost",
            port=19530,
            user="root",
            password=new_root_password
        )
        
        # 2. 创建应用专用用户
        app_password = generate_secure_password(16)
        print("👤 创建应用用户...")
        utility.create_user("app_user", app_password, using='default')
        print("✅ 应用用户创建成功")
        
        # 保存应用用户密码
        with open('.milvus_app_credentials', 'w') as f:
            f.write(f"username=app_user\npassword={app_password}")
        print("📝 应用用户凭据已保存到 .milvus_app_credentials 文件")
        
        # 3. 禁用默认用户（可选 - 注意：这会删除root用户的某些权限）
        print("⚠️  建议：创建管理员用户后，限制root用户的使用")
        
        print("\n🎉 安全初始化完成!")
        print("⚠️  重要提醒:")
        print("   1. 请妥善保管密码文件")
        print("   2. 删除 .milvus_root_password 文件（记住密码后）")
        print("   3. 在生产环境中使用应用用户连接")
        print("   4. 定期更换密码")
        
    except Exception as e:
        print(f"❌ 安全初始化失败: {e}")
        raise

if __name__ == "__main__":
    secure_milvus_setup()