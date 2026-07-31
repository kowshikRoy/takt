from unittest.mock import MagicMock
import sys

sys.modules['faster_whisper'] = MagicMock()
sys.modules['deep_translator'] = MagicMock()

import asyncio
from fastapi.testclient import TestClient
from server.main import app

def test_server_startup_and_endpoints():
    """Integration test checking FastAPI startup and basic endpoints using ASGI TestClient."""
    with TestClient(app) as client:
        # Test non-existent task status returns 404
        status_res = client.get("/status/non-existent-task-id")
        assert status_res.status_code == 404
        assert status_res.json() == {"detail": "Task not found"}

        # Test submit media endpoint
        submit_res = client.post("/submit-media", json={"url": "https://example.com/test.mp4"})
        assert submit_res.status_code == 200
        data = submit_res.json()
        assert "task_id" in data
        assert isinstance(data["task_id"], str)
