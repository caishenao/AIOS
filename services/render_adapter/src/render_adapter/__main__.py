import uvicorn
from render_adapter.config import get_settings

def main() -> None:
    settings = get_settings()
    uvicorn.run(
        "render_adapter.server:app",
        host=settings.HOST,
        port=settings.PORT,
        log_level=settings.LOG_LEVEL.lower(),
        reload=True  # useful for dev
    )

if __name__ == "__main__":
    main()
