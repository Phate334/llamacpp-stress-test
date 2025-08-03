# llama.cpp 壓力測試輔助工具

此專案提供一個 bash 腳本，作為 llama.cpp 的 `batched-bench` 工具的包裝器，旨在簡化基準測試和壓力測試，同時確保一致的輸出和元數據收集。

## 概述

`bench-helper.sh` 腳本自動化執行 `llama-batched-bench`，具備以下功能：

- **JSONL 輸出**：結果以 JSON Lines 格式保存，方便解析和分析。
- **環境元數據**：收集系統資訊、GPU 詳細資料及測試參數。
- **錯誤處理**：確保在執行檔缺失或配置無效時能夠優雅地處理。
- **輸出管理**：將結果和環境元數據保存到 `results/` 目錄中。

## 功能

- **自動元數據收集**：收集 CPU、GPU 和記憶體資訊。
- **強制 JSONL 輸出**：強制輸出格式為 JSONL，確保一致性。
- **靈活的參數處理**：支援所有 `llama-batched-bench` 的參數。
- **環境資訊保存**：將環境詳細資料保存到獨立的 JSON 檔案中。

## 使用方法

### 基本執行

使用 `llama-batched-bench` 的參數執行腳本：

```bash
./bench-helper.sh -m model.gguf -c 2048 -b 512 -ub 256 -ngl 99
```

### 進階基準測試

加入額外參數進行詳細測試：

```bash
./bench-helper.sh -m model.gguf -c 4096 -b 1024 -ub 512 -ngl 99 \
    -npp 128,256,512 -ntg 128,256 -npl 1,2,4,8,16,32
```

### 指定輸出目錄

指定自定義的輸出目錄：

```bash
./bench-helper.sh -o /path/to/output -m model.gguf -c 2048 -b 512
```

## 輸出檔案

腳本會在 `results/` 目錄中生成以下檔案：

1. **基準測試結果** (`output.jsonl`)：包含逐行的測試結果。
2. **環境元數據** (`environment.json`)：包括系統資訊和測試參數。

### JSONL 輸出範例

```jsonl
{"n_kv_max": 2048, "n_batch": 512, "n_ubatch": 512, "flash_attn": 0, "is_pp_shared": 0, "n_gpu_layers": 99, "n_threads": 8, "n_threads_batch": 8, "pp": 128, "tg": 128, "pl": 1, "n_kv": 256, "t_pp": 0.233810, "speed_pp": 547.453064, "t_tg": 3.503684, "speed_tg": 36.532974, "t": 3.737494, "speed": 68.495094}
```

### 環境元數據範例

```json
{
  "timestamp": "2025-08-03T10:30:00Z",
  "bench_executable": "/app/llama-batched-bench",
  "bench_arguments": ["-m", "model.gguf", "-c", "2048", "-b", "512"],
  "gpu_info": {
    "name": "NVIDIA GeForce RTX 4090",
    "memory_total_mb": 24576
  },
  "cpu_info": {
    "model": "Intel(R) Xeon(R) CPU E5-2699 v4 @ 2.20GHz",
    "cores": 44
  },
  "memory_info": {
    "total_mb": 128000,
    "available_mb": 120000
  }
}
```

## 先決條件

- `llama-batched-bench` 可執行檔來自 llama.cpp
- 支援 CUDA 的 GPU
- GGUF 格式的模型檔案
- 用於收集 GPU 資訊的 `nvidia-smi`

## 安裝

```bash
# 克隆此專案
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test

# 使腳本可執行
chmod +x bench-helper.sh
```

## 授權

此專案的授權與其所屬的存儲庫相同。

## 致謝

- 作為 [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench` 工具的包裝器構建。
- 專為 GPU 壓力測試和性能驗證設計。
