import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.getenv("SECRET_KEY", "LABSYNC_SUPER_SECRET_KEY_ENTERPRISE_7.0")
DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./labsync.db")
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "480"))
CORS_ORIGINS = os.getenv("CORS_ORIGINS", "*")
SYNC_SERVER_PORT = int(os.getenv("SYNC_SERVER_PORT", "8000"))
ALGORITHM = "HS256"
