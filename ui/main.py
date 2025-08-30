from pathlib import Path

from fastapi import FastAPI
from fastapi.responses import FileResponse

from ui.config import settings

app = FastAPI(title=settings.project_name)


@app.get("/")
async def read_index():
    # 以檔案所在資料夾為基準，確保容器內或不同工作目錄下都能正確找到靜態檔案
    base_dir = Path(__file__).parent
    index_path = base_dir / "static" / "index.html"
    return FileResponse(index_path)
