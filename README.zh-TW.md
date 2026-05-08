# llama.cpp 壓力測試輔助工具

這是一個 Docker-based 的 `llama-batched-bench` 小包裝器。它會執行官方 llama.cpp 容器、保存 JSONL benchmark 結果，並透過簡單的結果檢視器瀏覽歷史紀錄。

![結果檢視器畫面示意](./demo.png)

## 快速開始

```bash
docker compose up test
```

結果會寫入 `results/YYYYMMDD_HHMMSS/`。

瀏覽歷史結果：

```bash
docker compose up server
# 開啟 http://localhost:8000/results.html
```

## 預設 Benchmark

內建的 `compose.yaml` 使用：

- 映像：`ghcr.io/ggml-org/llama.cpp:full-cuda-b9070`
- 模型：`unsloth/gemma-4-E2B-it-GGUF:Q4_K_M`
- Benchmark：`llama-batched-bench`
- 輸出：強制使用 `jsonl`
- 快取：將 `./model-cache` 掛載到 `/root/.cache`

目前 benchmark 參數：

```bash
-hf unsloth/gemma-4-E2B-it-GGUF:Q4_K_M \
-c 4096 --fit off \
-npp 256 -ntg 128 -npl 1,2,3
```

範例保留 llama.cpp 預設的 `-b` 和 `-ub`，讓 compose 維持簡單基準用途。

## 等效 Docker Run

```bash
docker run --rm --gpus all \
  -v "$(pwd)/model-cache:/root/.cache" \
  -v "$(pwd)/results:/app/results" \
  -v "$(pwd)/bench-helper.sh:/app/bench-helper.sh" \
  --entrypoint /app/bench-helper.sh \
  ghcr.io/ggml-org/llama.cpp:full-cuda-b9070 \
  -hf unsloth/gemma-4-E2B-it-GGUF:Q4_K_M \
  -c 4096 --fit off \
  -npp 256 -ntg 128 -npl 1,2,3
```

若要改用本地模型，將 `-hf ...` 換成 `-m /app/models/your-model.gguf`，並掛載你的 models 目錄。

## 輸出

每次執行會產生：

- `output.jsonl`：benchmark 結果列
- `environment.json`：時間、llama.cpp 版本、執行參數、GPU、CPU、RAM 資訊

結果檢視器位於 `results/results.html`，可瀏覽所有 timestamp 目錄。

## Batch 調參

使用 [`tune-batch.sh`](/home/phate/llamacpp-stress-test/tune-batch.sh) 掃描 `-b` 和 `-ub`：

```bash
./tune-batch.sh
```

自訂 sweep：

```bash
./tune-batch.sh -b 1024,2048,4096 -u 256,512,1024
```

`-b` 和 `-ub` 很吃硬體與 workload，請把最佳候選組合放回實際 server workload 驗證後再定案。

## 需求

- Docker
- [NVIDIA Container Toolkit](https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/latest/install-guide.html)

## 安裝

```bash
git clone https://github.com/Phate334/llamacpp-stress-test.git
cd llamacpp-stress-test
chmod +x bench-helper.sh tune-batch.sh
```

## 致謝

- 基於 [llama.cpp](https://github.com/ggml-org/llama.cpp) `batched-bench`
- 使用 [charts.css](https://github.com/ChartsCSS/charts.css) 顯示圖表
