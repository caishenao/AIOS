import asyncio
import uuid
from datetime import datetime
from typing import Any, Callable, Coroutine
from pydantic import BaseModel
import logging

logger = logging.getLogger(__name__)

class TaskInfo(BaseModel):
    id: str
    session_id: str
    status: str  # pending, running, completed, cancelled, background
    created_at: datetime
    result: dict[str, Any] | None = None

class TaskManager:
    def __init__(self) -> None:
        self.tasks: dict[str, TaskInfo] = {}
        self.background_jobs: set[asyncio.Task] = set()
        self.completion_callback: Callable[[str, dict[str, Any]], Coroutine[Any, Any, None]] | None = None

    def set_completion_callback(self, callback: Callable[[str, dict[str, Any]], Coroutine[Any, Any, None]]) -> None:
        """Set a callback to inject completion UI back to the surface."""
        self.completion_callback = callback

    def create_task(self, session_id: str, intent: str = "general") -> str:
        task_id = str(uuid.uuid4())
        self.tasks[task_id] = TaskInfo(
            id=task_id,
            session_id=session_id,
            status="running",
            created_at=datetime.utcnow()
        )
        return task_id

    def transition_to_background(self, task_id: str, coroutine: Coroutine[Any, Any, Any]) -> None:
        """Moves an interrupted operation into a background asyncio task."""
        if task_id not in self.tasks:
            return

        self.tasks[task_id].status = "background"
        
        async def background_wrapper() -> None:
            try:
                result = await coroutine
                self.tasks[task_id].status = "completed"
                self.tasks[task_id].result = {"data": result}
                await self._notify_completion(task_id, result)
            except asyncio.CancelledError:
                self.tasks[task_id].status = "cancelled"
            except Exception as e:
                logger.error(f"Background task {task_id} failed: {e}")
                self.tasks[task_id].status = "cancelled"
                self.tasks[task_id].result = {"error": str(e)}
            finally:
                self.background_jobs.discard(asyncio.current_task())

        job = asyncio.create_task(background_wrapper())
        self.background_jobs.add(job)

    async def _notify_completion(self, task_id: str, result: Any) -> None:
        if not self.completion_callback:
            return
            
        task = self.tasks[task_id]
        
        # Construct a synthetic InfoCard payload to inject into the UI
        completion_payload = {
            "surfaceId": "main",
            "root": {
                "component": "InfoCard",
                "props": {
                    "title": "Background Task Completed",
                    "body": f"Task finished: {result}",
                    "theme": {
                        "color.surface": "#1E2A1E",
                        "color.accent": "#4CAF50"
                    }
                }
            }
        }
        await self.completion_callback(task.session_id, completion_payload)

    def get_task(self, task_id: str) -> TaskInfo | None:
        return self.tasks.get(task_id)

    def cancel_task(self, task_id: str) -> bool:
        if task_id in self.tasks:
            self.tasks[task_id].status = "cancelled"
            # Actual coroutine cancellation would require tracking the specific asyncio.Task
            return True
        return False

    def list_tasks(self, session_id: str) -> list[TaskInfo]:
        return [t for t in self.tasks.values() if t.session_id == session_id]

task_manager = TaskManager()
