import asyncio
import pytest
from render_adapter.tasks import TaskManager

@pytest.fixture
def task_manager() -> TaskManager:
    return TaskManager()

@pytest.mark.asyncio
async def test_create_and_transition_to_background(task_manager: TaskManager) -> None:
    session_id = "test-session"
    
    # Track completion callbacks
    notifications = []
    
    async def mock_completion_callback(sess_id: str, payload: dict) -> None:
        notifications.append((sess_id, payload))
        
    task_manager.set_completion_callback(mock_completion_callback)
    
    task_id = task_manager.create_task(session_id)
    assert task_id in task_manager.tasks
    assert task_manager.tasks[task_id].status == "running"
    
    # Mock a long running background coroutine
    async def long_running_task() -> str:
        await asyncio.sleep(0.1)
        return "done"
        
    task_manager.transition_to_background(task_id, long_running_task())
    
    # Assert status changed immediately
    assert task_manager.tasks[task_id].status == "background"
    
    # Wait for the background task to finish
    await asyncio.sleep(0.15)
    
    assert task_manager.tasks[task_id].status == "completed"
    assert task_manager.tasks[task_id].result == {"data": "done"}
    assert len(notifications) == 1
    
    # Verify the callback payload
    sess, payload = notifications[0]
    assert sess == session_id
    assert payload["root"]["component"] == "InfoCard"
    assert "Background Task Completed" in payload["root"]["props"]["title"]

@pytest.mark.asyncio
async def test_background_task_cancellation(task_manager: TaskManager) -> None:
    session_id = "test-session-2"
    task_id = task_manager.create_task(session_id)
    
    async def infinite_task() -> str:
        while True:
            await asyncio.sleep(0.1)
            
    task_manager.transition_to_background(task_id, infinite_task())
    assert task_manager.tasks[task_id].status == "background"
    
    # Yield to let the background wrapper start
    await asyncio.sleep(0.01)
    
    # We cancel it by fetching the task from the set
    for job in list(task_manager.background_jobs):
        job.cancel()
        
    # Yield to let cancellation bubble up
    await asyncio.sleep(0.1)
    
    assert task_manager.tasks[task_id].status == "cancelled"
