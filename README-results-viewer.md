# HTML Results Viewer

The `results-viewer.html` file provides a web-based interface for visualizing llama.cpp batched-bench results.

## Features

- **File Upload**: Select and load JSONL result files from batched-bench
- **Data Visualization**: Interactive table with sorting and filtering capabilities
- **Statistics Overview**: Real-time statistics including total tests, average/min/max speeds, and average time
- **Field Mapping**: Correctly maps batched-bench output fields to user-friendly column names
- **Responsive Design**: Works on desktop and mobile devices
- **Pure Frontend**: No server required - works offline by opening the HTML file directly

## Usage

1. **Open the viewer**: Open `results-viewer.html` in any modern web browser
2. **Upload results**: Click "Select JSONL File" and choose your batched-bench output file
3. **View results**: Browse the data table and statistics overview
4. **Sort data**: Click any column header to sort by that field
5. **Filter data**: Use the filter controls to narrow down results
   - Select a field to filter by (PP, TG, B, N_KV)
   - Enter a value to filter for
6. **Analyze**: Review the statistics and identify performance patterns

## Field Mappings

The viewer maps batched-bench JSON fields to readable column headers:

| Display Name | JSON Field | Description |
|--------------|------------|-------------|
| PP | `pp` | Prompt tokens per batch |
| TG | `tg` | Generated tokens per batch |
| B | `pl` | Number of batches |
| N_KV | `n_kv` | Required KV cache size |
| T_PP (s) | `t_pp` | Prompt processing time |
| S_PP (t/s) | `speed_pp` | Prompt processing speed |
| T_TG (s) | `t_tg` | Time to generate all batches |
| S_TG (t/s) | `speed_tg` | Text generation speed |
| T (s) | `t` | Total time |
| S (t/s) | `speed` | Total speed |

## Sample JSONL Format

The viewer expects JSONL files with the following structure:

```jsonl
{"n_kv_max": 2048, "n_batch": 512, "n_ubatch": 512, "flash_attn": 0, "is_pp_shared": 0, "n_gpu_layers": 99, "n_threads": 8, "n_threads_batch": 8, "pp": 128, "tg": 128, "pl": 1, "n_kv": 256, "t_pp": 0.233810, "speed_pp": 547.453064, "t_tg": 3.503684, "speed_tg": 36.532974, "t": 3.737494, "speed": 68.495094}
{"n_kv_max": 2048, "n_batch": 512, "n_ubatch": 512, "flash_attn": 0, "is_pp_shared": 0, "n_gpu_layers": 99, "n_threads": 8, "n_threads_batch": 8, "pp": 256, "tg": 128, "pl": 1, "n_kv": 384, "t_pp": 0.421234, "speed_pp": 608.123456, "t_tg": 4.234567, "speed_tg": 30.234567, "t": 4.655801, "speed": 82.567123}
```

## Browser Compatibility

The viewer is compatible with modern browsers that support:
- ES6 JavaScript features
- HTML5 File API
- Canvas 2D API
- CSS Grid and Flexbox

Tested on Chrome, Firefox, Safari, and Edge.