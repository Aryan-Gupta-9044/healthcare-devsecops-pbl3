import sys
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))
from app import create_app  # noqa: E402


@pytest.fixture()
def client(monkeypatch):
    for k in ("APP_VERSION", "DEPLOYMENT_COLOR", "RELEASE_LABEL"):
        monkeypatch.delenv(k, raising=False)
    return create_app().test_client()


def test_health(client):
    r = client.get("/health")
    assert r.status_code == 200 and r.get_json() == {"status": "healthy"}


def test_status_defaults(client):
    j = client.get("/api/status").get_json()
    assert j["status"] == "ok" and j["version"] == "1.0.0" and j["color"] == "standard"
    assert j["patients"] == 6 and j["pod"]


@pytest.mark.parametrize("color,version,label", [("blue", "1.0.0", "Blue Release"), ("green", "2.0.0", "Green Release")])
def test_blue_green_identity(monkeypatch, color, version, label):
    monkeypatch.setenv("DEPLOYMENT_COLOR", color)
    monkeypatch.setenv("APP_VERSION", version)
    c = create_app().test_client()
    j = c.get("/api/status").get_json()
    assert (j["color"], j["version"], j["label"]) == (color, version, label)
    html = c.get("/").get_data(as_text=True)
    assert f"v{version}" in html and f"release-{color}" in html


def test_invalid_color_falls_back(monkeypatch):
    monkeypatch.setenv("DEPLOYMENT_COLOR", "<script>")
    assert create_app().test_client().get("/api/status").get_json()["color"] == "standard"


def test_index_renders_dashboard(client):
    html = client.get("/").get_data(as_text=True)
    assert "Patient records" in html and "Register patient" in html


def test_list_patients_fields(client):
    rows = client.get("/api/patients").get_json()
    assert len(rows) == 6
    assert set(rows[0]) == {"id", "name", "age", "department", "status"}


def test_register_patient(client):
    r = client.post("/api/patients", json={"name": "Test Person", "age": 40, "department": "Cardiology"})
    assert r.status_code == 201
    assert r.get_json()["id"] == "P-1007" and r.get_json()["status"] == "Scheduled"
    assert client.get("/api/stats").get_json()["total"] == 7


@pytest.mark.parametrize("payload", [
    {"name": "", "age": 30, "department": "Cardiology"},
    {"name": "<b>x</b>", "age": 30, "department": "Cardiology"},
    {"name": "Ok Name", "age": -1, "department": "Cardiology"},
    {"name": "Ok Name", "age": "abc", "department": "Cardiology"},
    {"name": "Ok Name", "age": 30, "department": "Nope"},
    {"name": "Ok Name", "age": 30, "department": "Cardiology", "status": "Nope"},
])
def test_register_rejects_bad_input(client, payload):
    assert client.post("/api/patients", json=payload).status_code == 400


def test_stats(client):
    s = client.get("/api/stats").get_json()
    assert s["total"] == 6 and sum(s["by_status"].values()) == 6 and s["average_age"] > 0


def test_security_headers(client):
    h = client.get("/").headers
    assert h["X-Content-Type-Options"] == "nosniff" and h["X-Frame-Options"] == "DENY"
