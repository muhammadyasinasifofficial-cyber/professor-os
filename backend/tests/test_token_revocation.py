import pytest
from httpx import AsyncClient, ASGITransport
from app.main import app

PROFESSOR_EMAIL = "dr.tariq@professoros.edu.pk"
PROFESSOR_PASSWORD = "professor123"


@pytest.mark.asyncio
async def test_logout_revokes_token_and_rejects_subsequent_calls():
    """Verify that logging out invalidates the token and prevents further access."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        # 1. Login to obtain access token
        res_login = await client.post(
            "/api/v1/auth/login",
            json={"email": PROFESSOR_EMAIL, "password": PROFESSOR_PASSWORD},
        )
        assert res_login.status_code == 200
        token = res_login.json()["access_token"]
        headers = {"Authorization": f"Bearer {token}"}

        # 2. Token should be valid for authenticated requests
        res_me = await client.get("/api/v1/users/me", headers=headers)
        assert res_me.status_code == 200

        # 3. Call logout
        res_logout = await client.post("/api/v1/auth/logout", headers=headers)
        assert res_logout.status_code == 200
        assert res_logout.json()["message"] == "Logged out successfully."

        # 4. Same token should now be rejected as revoked (401)
        res_me_after = await client.get("/api/v1/users/me", headers=headers)
        assert res_me_after.status_code == 401
        assert "revoked" in res_me_after.json()["detail"].lower()


@pytest.mark.asyncio
async def test_serve_flutter_path_traversal_blocked():
    """Verify that path traversal attempts to sensitive files are blocked with 403."""
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        res = await client.get("/../../backend/.env")
        assert res.status_code in (403, 404)
        if res.status_code == 403:
            assert res.json()["detail"] == "Access denied."
