from datetime import datetime, timezone

import pytest
from passlib.context import CryptContext
from sqlalchemy import select

from app.models.device import Device
from app.models.usuario import UserRole, Usuario

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


@pytest.mark.asyncio
async def test_register_device(client, session):
    payload = {"device_id": "dev-001", "device_name": "Lab-PC-1", "os": "Windows"}
    response = await client.post("/api/auth/register-device", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["device_id"] == "dev-001"
    assert data["is_approved"] is True

    result = await session.execute(select(Device).where(Device.id == "dev-001"))
    device = result.scalar_one_or_none()
    assert device is not None
    assert device.device_name == "Lab-PC-1"


@pytest.mark.asyncio
async def test_register_device_duplicate(client, session):
    device = Device(
        id="dev-dupe", device_name="Original", os="Linux", is_approved=True,
        approved_at=datetime.now(timezone.utc),
    )
    session.add(device)
    await session.commit()

    payload = {"device_id": "dev-dupe", "device_name": "Duplicate", "os": "macOS"}
    response = await client.post("/api/auth/register-device", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["device_id"] == "dev-dupe"


@pytest.mark.asyncio
async def test_login_success(client, session):
    user = Usuario(
        id="usr-test",
        nombre="Test User",
        cargo="Tecnico",
        rol=UserRole.LABORATORIO,
        pin_hash=pwd_context.hash("1234"),
        pass_hash=pwd_context.hash("password"),
        activo=True,
    )
    session.add(user)
    await session.commit()

    response = await client.post("/api/auth/login", json={
        "user_id": "usr-test",
        "pin": "1234",
        "device_id": "dev-login",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["token_type"] == "bearer"
    assert data["user_id"] == "usr-test"
    assert data["nombre"] == "Test User"
    assert data["rol"] == "LABORATORIO"
    assert "access_token" in data


@pytest.mark.asyncio
async def test_login_wrong_pin(client, session):
    user = Usuario(
        id="usr-test2",
        nombre="Test User 2",
        cargo="Tecnico",
        rol=UserRole.LABORATORIO,
        pin_hash=pwd_context.hash("1234"),
        activo=True,
    )
    session.add(user)
    await session.commit()

    response = await client.post("/api/auth/login", json={
        "user_id": "usr-test2",
        "pin": "9999",
        "device_id": "dev-login",
    })
    assert response.status_code == 400
    assert "Credenciales incorrectas" in response.json()["detail"]


@pytest.mark.asyncio
async def test_login_inactive_user(client, session):
    user = Usuario(
        id="usr-inactive",
        nombre="Inactive User",
        cargo="Tecnico",
        rol=UserRole.LABORATORIO,
        pin_hash=pwd_context.hash("1234"),
        activo=False,
    )
    session.add(user)
    await session.commit()

    response = await client.post("/api/auth/login", json={
        "user_id": "usr-inactive",
        "pin": "1234",
        "device_id": "dev-login",
    })
    assert response.status_code == 400
    assert "inactivo" in response.json()["detail"]


@pytest.mark.asyncio
async def test_login_with_password(client, session):
    user = Usuario(
        id="usr-pass",
        nombre="Password User",
        cargo="Tecnico",
        rol=UserRole.ADMIN,
        pass_hash=pwd_context.hash("securepass"),
        activo=True,
    )
    session.add(user)
    await session.commit()

    response = await client.post("/api/auth/login", json={
        "user_id": "usr-pass",
        "password": "securepass",
        "device_id": "dev-pw",
    })
    assert response.status_code == 200
    data = response.json()
    assert data["user_id"] == "usr-pass"
    assert data["rol"] == "ADMIN"
