import pytest
from datetime import datetime, timedelta, timezone
from jose import jwt

from app.core.config import Settings
from app.core.security import (
    create_access_token,
    decode_access_token,
    hash_password,
    verify_password,
    pwd_context,
)


@pytest.fixture
def test_settings():
    return Settings(
        secret_key="test-secret-key-for-testing-only-32chars!",
        algorithm="HS256",
        access_token_expire_minutes=30,
    )


class TestPasswordHashing:
    def test_hash_password_returns_different_hash(self):
        password = "test_password_123"
        hash1 = hash_password(password)
        hash2 = hash_password(password)
        assert hash1 != hash2

    def test_verify_password_correct(self):
        password = "secure_password"
        hashed = hash_password(password)
        assert verify_password(password, hashed) is True

    def test_verify_password_incorrect(self):
        password = "secure_password"
        hashed = hash_password(password)
        assert verify_password("wrong_password", hashed) is False

    def test_pwd_context_is_shared(self):
        from app.modules.auth.router import pwd_context as auth_ctx
        from app.modules.users.router import pwd_context as users_ctx
        assert auth_ctx is users_ctx


class TestJWTTokens:
    def test_create_and_decode_token(self, test_settings):
        data = {"sub": "usr-admin", "rol": "ADMIN", "nombre": "Test User"}
        token = create_access_token(data)
        decoded = decode_access_token(token)
        assert decoded is not None
        assert decoded["sub"] == "usr-admin"
        assert decoded["rol"] == "ADMIN"

    def test_decode_expired_token(self, test_settings):
        data = {"sub": "usr-admin", "rol": "ADMIN"}
        token = jwt.encode(
            {
                **data,
                "exp": datetime.now(timezone.utc) - timedelta(hours=1),
            },
            test_settings.secret_key,
            algorithm=test_settings.algorithm,
        )
        decoded = decode_access_token(token)
        assert decoded is None

    def test_decode_invalid_token(self, test_settings):
        decoded = decode_access_token("invalid.token.here")
        assert decoded is None

    def test_decode_wrong_secret_token(self, test_settings):
        data = {"sub": "usr-admin", "rol": "ADMIN"}
        token = jwt.encode(
            {
                **data,
                "exp": datetime.now(timezone.utc) + timedelta(hours=1),
            },
            "wrong-secret-key",
            algorithm="HS256",
        )
        decoded = decode_access_token(token)
        assert decoded is None


class TestSettings:
    def test_secret_key_validation_rejects_default(self):
        settings = Settings(secret_key="change-me-in-production-use-a-strong-random-key")
        assert settings.secret_key != "change-me-in-production-use-a-strong-random-key"
        assert len(settings.secret_key) >= 32

    def test_secret_key_validation_rejects_empty(self):
        settings = Settings(secret_key="")
        assert settings.secret_key != ""
        assert len(settings.secret_key) >= 32

    def test_secret_key_validation_allows_strong_key(self):
        strong_key = "a" * 64
        settings = Settings(secret_key=strong_key)
        assert settings.secret_key == strong_key
