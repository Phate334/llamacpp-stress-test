"""Runs results API 與輔助函式。

提供列出結果目錄、讀取 environment.json 與 output.jsonl 內容的端點。
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

from fastapi import APIRouter, HTTPException

from ui.config import settings

router = APIRouter(prefix="/runs", tags=["runs"])

RESULT_DIR = Path(settings.result_dir)


def _is_run_dir(p: Path) -> bool:
    return (
        p.is_dir()
        and (p / "environment.json").exists()
        and (p / "output.jsonl").exists()
    )


def list_runs() -> list[str]:
    if not RESULT_DIR.exists():
        return []
    runs = [
        d.name for d in sorted(RESULT_DIR.iterdir(), reverse=True) if _is_run_dir(d)
    ]
    return runs


def get_run_path(run_id: str) -> Path:
    p = RESULT_DIR / run_id
    if not _is_run_dir(p):
        raise HTTPException(status_code=404, detail="找不到指定的執行結果目錄")
    return p


def read_environment_json(run_id: str) -> dict[str, Any]:
    p = get_run_path(run_id) / "environment.json"
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except FileNotFoundError:  # pragma: no cover - defensive
        raise HTTPException(status_code=404, detail="environment.json 不存在")
    except json.JSONDecodeError as e:  # pragma: no cover
        raise HTTPException(status_code=500, detail=f"environment.json 解析失敗: {e}")


def read_output_jsonl(run_id: str) -> list[dict[str, Any]]:
    p = get_run_path(run_id) / "output.jsonl"
    if not p.exists():
        raise HTTPException(status_code=404, detail="output.jsonl 不存在")
    rows: list[dict[str, Any]] = []
    with p.open("r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                rows.append(json.loads(line))
            except json.JSONDecodeError:  # pragma: no cover
                rows.append({"_raw": line, "_error": "JSONDecodeError"})
    return rows


def get_run_files(run_id: str) -> list[str]:
    p = get_run_path(run_id)
    return sorted([child.name for child in p.iterdir() if child.is_file()])


@router.get("/", summary="列出所有執行結果目錄")
def api_list_runs() -> list[str]:  # 簡單回傳清單
    return list_runs()


@router.get("/{run_id}/environment", summary="取得 environment.json")
def api_environment(run_id: str) -> dict[str, Any]:
    return read_environment_json(run_id)


@router.get("/{run_id}/output", summary="取得 output.jsonl 內容")
def api_output(run_id: str):
    return {"rows": read_output_jsonl(run_id)}