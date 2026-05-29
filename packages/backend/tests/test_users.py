import pytest
from passlib.context import CryptContext
from sqlalchemy import select

from app.core.security import create_access_token
from app.models.usuario import UserRole, Usuario

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")


def _admin_token():
    return create_access_token({"sub": "usr-admin", "rol": "ADMIN", "nombre": "Admin"})


def _user_token():
    return create_access_token({"sub": "usr-regular", "rol": "LABORATORIO", "nombre": "User"})


@pytest.mark.asyncio
async def test_list_users_requires_auth(client):
    response = await client.get("/api/users")
    assert response.status_code == 403 or response.status_code == 401


@pytest.mark.asyncio
async def test_list_users(client, session):
    session.add_all([
        Usuario(id="u1", nombre="Alice", cargo="Bio", rol=UserRole.LABORATORIO, activo=True),
        Usuario(id="u2", nombre="Bob", cargo="Chem", rol=UserRole.ADMIN, activo=True),
    ])
    await session.commit()

    token = _admin_token()
    response = await client.get("/api/users", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    data = response.json()
    assert len(data) >= 2
    ids = [u["id"] for u in data]
    assert "u1" in ids
    assert "u2" in ids


@pytest.mark.asyncio
async def test_get_user(client, session):
    session.add(Usuario(id="u1", nombre="Alice", cargo="Bio", rol=UserRole.LABORATORIO, activo=True))
    await session.commit()

    token = _admin_token()
    response = await client.get("/api/users/u1", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["nombre"] == "Alice"


@pytest.mark.asyncio
async def test_get_user_not_found(client):
    token = _admin_token()
    response = await client.get("/api/users/nonexistent", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_create_user(client, session):
    token = _admin_token()
    payload = {
        "id": "usr-new",
        "nombre": "New User",
        "cargo": "Tecnico",
        "rol": "LABORATORIO",
        "pin": "1234",
    }
    response = await client.post("/api/users", json=payload, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["success"] is True
    assert response.json()["user"]["id"] == "usr-new"

    result = await session.execute(select(Usuario).where(Usuario.id == "usr-new"))
    user = result.scalar_one_or_none()
    assert user is not None
    assert user.nombre == "New User"


@pytest.mark.asyncio
async def test_create_user_duplicate(client, session):
    session.add(Usuario(id="usr-dupe", nombre="Existing", cargo="X", rol=UserRole.LABORATORIO, activo=True))
    await session.commit()

    token = _admin_token()
    payload = {"id": "usr-dupe", "nombre": "Dupe", "cargo": "X", "rol": "LABORATORIO"}
    response = await client.post("/api/users", json=payload, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 400
    assert "ya existe" in response.json()["detail"]


@pytest.mark.asyncio
async def test_create_user_pin_too_short(client):
    token = _admin_token()
    payload = {"id": "usr-short", "nombre": "Short", "cargo": "X", "rol": "LABORATORIO", "pin": "12"}
    response = await client.post("/api/users", json=payload, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 400
    assert "4 caracteres" in response.json()["detail"]


@pytest.mark.asyncio
async def test_create_user_password_too_short(client):
    token = _admin_token()
    payload = {"id": "usr-pshort", "nombre": "Short", "cargo": "X", "rol": "LABORATORIO", "password": "ab"}
    response = await client.post("/api/users", json=payload, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 400
    assert "6 caracteres" in response.json()["detail"]


@pytest.mark.asyncio
async def test_update_user(client, session):
    session.add(Usuario(id="usr-upd", nombre="Original", cargo="X", rol=UserRole.LABORATORIO, activo=True))
    await session.commit()

    token = _admin_token()
    response = await client.put("/api/users/usr-upd", json={"nombre": "Updated"}, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["success"] is True

    result = await session.execute(select(Usuario).where(Usuario.id == "usr-upd"))
    user = result.scalar_one_or_none()
    assert user.nombre == "Updated"


@pytest.mark.asyncio
async def test_update_user_not_found(client):
    token = _admin_token()
    response = await client.put("/api/users/nonexistent", json={"nombre": "X"}, headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 404


@pytest.mark.asyncio
async def test_delete_user(client, session):
    session.add(Usuario(id="usr-del", nombre="To Delete", cargo="X", rol=UserRole.LABORATORIO, activo=True))
    await session.commit()

    token = _admin_token()
    response = await client.delete("/api/users/usr-del", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200
    assert response.json()["success"] is True

    result = await session.execute(select(Usuario).where(Usuario.id == "usr-del"))
    user = result.scalar_one_or_none()
    assert user is not None
    assert user.activo is False


@pytest.mark.asyncio
async def test_delete_self_not_allowed(client, session):
    session.add(Usuario(id="usr-self", nombre="Self", cargo="X", rol=UserRole.ADMIN, activo=True))
    await session.commit()

    token = create_access_token({"sub": "usr-self", "rol": "ADMIN", "nombre": "Self"})
    response = await client.delete("/api/users/usr-self", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 400
    assert "propio" in response.json()["detail"]


@pytest.mark.asyncio
async def test_reactivate_user(client, session):
    session.add(Usuario(id="usr-inact", nombre="Inactive", cargo="X", rol=UserRole.LABORATORIO, activo=False))
    await session.commit()

    token = _admin_token()
    response = await client.post("/api/users/usr-inact/reactivate", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 200

    result = await session.execute(select(Usuario).where(Usuario.id == "usr-inact"))
    user = result.scalar_one_or_none()
    assert user.activo is True


@pytest.mark.asyncio
async def test_reactivate_user_not_found(client):
    token = _admin_token()
    response = await client.post("/api/users/nonexistent/reactivate", headers={"Authorization": f"Bearer {token}"})
    assert response.status_code == 404
