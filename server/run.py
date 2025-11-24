"""
服务启动脚本
"""
import uvicorn
from main import app

if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=3001,
        reload=True,  # 开发模式下启用自动重载
        log_level="info"
    )
