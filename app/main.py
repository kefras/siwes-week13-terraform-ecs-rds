import logging
import os
import time
from contextlib import asynccontextmanager
import ssl

import pymysql
from fastapi import FastAPI, HTTPException

logger = logging.getLogger("uvicorn.error")

def check_database():
    # ECS injects these two keys; never log credentials or connection exceptions.
    tls = ssl.create_default_context(cafile=os.environ["DB_SSL_CA"])
    with pymysql.connect(
        host=os.environ["DB_HOST"], port=int(os.getenv("DB_PORT", "3306")),
        user=os.environ["DB_USERNAME"], password=os.environ["DB_PASSWORD"],
        database=os.getenv("DB_NAME", "appdb"), ssl=tls,
        connect_timeout=3, read_timeout=3, write_timeout=3,
    ) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
            if cursor.fetchone() != (1,):
                raise RuntimeError("Database probe failed")

@asynccontextmanager
async def lifespan(app):
    for attempt in range(12):
        try:
            check_database()
            logger.info("Database startup check succeeded: SELECT 1 over verified TLS")
            break
        except Exception:
            if attempt == 11:
                raise RuntimeError("Database startup check failed; inspect network, secret and TLS configuration") from None
            time.sleep(5)
    yield

app = FastAPI(title="Week 13 ECS Application", lifespan=lifespan)

@app.get("/")
def home():
    return {"message": "Week 13 ECS application is running", "environment": os.getenv("APP_ENV", "unknown")}

@app.get("/health")
def health():
    # ALB readiness is evidence of a real query, not a static success response.
    try:
        check_database()
    except Exception:
        raise HTTPException(status_code=503, detail="Database unavailable") from None
    return {"status": "ok", "database": "connected"}
