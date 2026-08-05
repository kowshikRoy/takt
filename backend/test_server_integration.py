from unittest.mock import MagicMock
import sys

sys.modules['faster_whisper'] = MagicMock()
sys.modules['deep_translator'] = MagicMock()

import asyncio
from fastapi.testclient import TestClient
from main import app

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


def test_sync_merges_xp_events_and_curriculum_progress_across_devices():
    """Phase 5: /api/sync must merge xp_events/curriculum_progress additively
    across devices (union by id), never lose data to a last-write-wins overwrite,
    and stay idempotent when a device re-pushes an already-synced payload."""
    import uuid

    with TestClient(app) as client:
        username = f"sync_test_{uuid.uuid4().hex[:8]}"
        register_res = client.post("/api/auth/register", json={"username": username, "password": "testpass123"})
        assert register_res.status_code == 200
        headers = {"x-auth-token": register_res.json()["token"]}

        device_a_payload = {
            "xp_events": [
                {"id": "xp_1", "userId": "u1", "source": "exercise_correct", "amount": 10, "timestamp": "2026-01-01T10:00:00"},
                {"id": "xp_2", "userId": "u1", "source": "review_completed", "amount": 5, "timestamp": "2026-01-01T10:05:00"},
            ],
            "streak_freezes": 1,
            "curriculum_progress": ["unit_1_vocab", "unit_1_gender"],
        }
        assert client.post("/api/sync", json=device_a_payload, headers=headers).status_code == 200

        # A second device that never synced before should see device A's state.
        remote = client.get("/api/sync", headers=headers).json()
        assert {e["id"] for e in remote["xp_events"]} == {"xp_1", "xp_2"}
        assert set(remote["curriculum_progress"]) == {"unit_1_vocab", "unit_1_gender"}

        # Device B pushes its own, disjoint contribution.
        device_b_payload = {
            "xp_events": [
                {"id": "xp_3", "userId": "u1", "source": "exercise_correct", "amount": 10, "timestamp": "2026-01-01T11:00:00"},
            ],
            "curriculum_progress": ["unit_1_compound"],
        }
        assert client.post("/api/sync", json=device_b_payload, headers=headers).status_code == 200

        merged = client.get("/api/sync", headers=headers).json()
        assert {e["id"] for e in merged["xp_events"]} == {"xp_1", "xp_2", "xp_3"}
        assert set(merged["curriculum_progress"]) == {"unit_1_vocab", "unit_1_gender", "unit_1_compound"}

        # Re-pushing device A's original (now-stale) payload must not duplicate events.
        client.post("/api/sync", json=device_a_payload, headers=headers)
        final = client.get("/api/sync", headers=headers).json()
        assert len(final["xp_events"]) == 3
