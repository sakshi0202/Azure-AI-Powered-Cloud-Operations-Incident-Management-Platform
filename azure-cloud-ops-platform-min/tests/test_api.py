from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health():
    r = client.get('/health')
    assert r.status_code == 200
    assert r.json()['status'] == 'healthy'

def test_failure_toggle():
    assert client.post('/simulate/failure', json={'mode': 'error'}).status_code == 200
    assert client.get('/health').status_code == 503
    assert client.post('/simulate/failure', json={'mode': 'clear'}).status_code == 200
    assert client.get('/health').status_code == 200
