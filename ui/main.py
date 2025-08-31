from pathlib import Path

from fastapi import FastAPI, Request
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates

from ui.config import settings
from ui.api import router as runs_router

# 建立 FastAPI 主應用
app = FastAPI(title=settings.project_name)

# 掛載靜態檔案 (CSS 等)
static_dir = Path(__file__).parent / "static"
if static_dir.exists():
	app.mount("/static", StaticFiles(directory=str(static_dir)), name="static")

# 設定模板路徑
templates_dir = Path(__file__).parent / "templates"
templates = Jinja2Templates(directory=str(templates_dir))

# 掛載 runs API router
app.include_router(runs_router, prefix="/api")


@app.get("/", include_in_schema=False)
async def index(request: Request):
	# 導向到前端 HTML 頁面 (同樣使用模板)
	from ui.api import list_runs  # 延遲匯入避免循環

	runs = list_runs()
	return templates.TemplateResponse(
		"index.html",
		{
			"request": request,
			"runs": runs,
			"project_name": settings.project_name,
		},
	)


@app.get("/runs/{run_id}", include_in_schema=False)
async def run_detail(request: Request, run_id: str):
	from ui.api import get_run_files, read_environment_json  # 延遲匯入

	files = get_run_files(run_id)
	env_data = read_environment_json(run_id)
	return templates.TemplateResponse(
		"run_detail.html",
		{
			"request": request,
			"run_id": run_id,
			"files": files,
			"env": env_data,
			"project_name": settings.project_name,
		},
	)

