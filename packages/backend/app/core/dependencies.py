from typing import Annotated
import logging

from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_session
from app.core.security import decode_access_token
from app.services.rate_limiter import RateLimiter

logger = logging.getLogger(__name__)

bearer_scheme = HTTPBearer()
rate_limiter = RateLimiter()

ADMIN_ROLES = {"ADMIN"}
JEFE_ROLES = {"ADMIN", "JEFE"}
AUDITOR_ROLES = {"ADMIN", "JEFE", "AUDITOR"}
ALL_AUTHENTICATED_ROLES = {"ADMIN", "JEFE", "LABORATORIO", "AUDITOR", "DUENO"}


async def get_current_user(
    credentials: Annotated[HTTPAuthorizationCredentials, Depends(bearer_scheme)],
    session: Annotated[AsyncSession, Depends(get_session)],
):
    payload = decode_access_token(credentials.credentials)
    if payload is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED)
    return payload


def require_roles(*allowed_roles: str):
    def role_checker(
        current_user: dict = Depends(get_current_user),
    ):
        user_role = current_user.get("rol", "")
        if user_role not in allowed_roles:
            logger.warning(
                "Access denied: user %s (role=%s) required one of %s",
                current_user.get("sub"),
                user_role,
                allowed_roles,
            )
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="No tienes permiso para realizar esta accion",
            )
        return current_user
    return role_checker


async def rate_limit(key: str = "default"):
    if not rate_limiter.is_allowed(key):
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="Demasiadas solicitudes. Intenta de nuevo mas tarde.",
        )
    return True
