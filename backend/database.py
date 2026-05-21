import sys
import sqlcipher3
sys.modules["sqlite3"] = sqlcipher3

from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, declarative_base

from config import DATABASE_URL, SECRET_KEY

DB_PASSPHRASE = SECRET_KEY[:32]

engine = create_engine(
    DATABASE_URL, connect_args={"check_same_thread": False}
)

@event.listens_for(engine, "connect")
def set_sqlcipher_key(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute(f"PRAGMA key = '{DB_PASSPHRASE}'")
    cursor.execute("PRAGMA cipher_use_hmac = OFF")
    cursor.execute("PRAGMA kdf_iter = 64000")
    cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
