from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.v1 import ad, auth, boost, chat, discover, likes, matches, notifications, onboarding, reports, swipes, users, vip
from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    yield


app = FastAPI(title="Binge Date API", version="0.1.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router, prefix="/api/v1")
app.include_router(users.router, prefix="/api/v1")
app.include_router(discover.router, prefix="/api/v1")
app.include_router(swipes.router, prefix="/api/v1")
app.include_router(likes.router, prefix="/api/v1")
app.include_router(matches.router, prefix="/api/v1")
app.include_router(vip.router, prefix="/api/v1")
app.include_router(boost.router, prefix="/api/v1")
app.include_router(onboarding.router, prefix="/api/v1")
app.include_router(ad.router, prefix="/api/v1")
app.include_router(notifications.router, prefix="/api/v1")
app.include_router(reports.router, prefix="/api/v1")
app.include_router(chat.router)  # WS ve REST chat prefix'siz eklenir


@app.get("/health")
async def health():
    return {"status": "ok"}
