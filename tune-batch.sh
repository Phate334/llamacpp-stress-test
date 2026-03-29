#!/bin/bash
set -euo pipefail

BASE_DIR="$(dirname "$(realpath "$0")")"

SERVICE_NAME="test"
BATCH_VALUES="1024,2048,4096"
UBATCH_VALUES="256,512,1024,2048"
REPETITIONS="3"
OUTPUT_DIR=""

DEFAULT_BENCH_ARGS=(
    -hf "lmstudio-community/gemma-3-1B-it-qat-GGUF:Q4_0"
    -ngl "99"
    -fa "1"
    -ctk "f16"
    -ctv "f16"
    -p "512"
    -n "128"
)

BENCH_ARGS=()

show_help() {
    cat <<'EOF'
Usage:
  ./tune-batch.sh [options] [-- extra llama-bench args]

Runs a batch/ubatch sweep with:
  docker compose run --rm --entrypoint /app/llama-bench <service> ...

Options:
  -b, --batch-values CSV     logical batch-size values to test
                             default: 1024,2048,4096
  -u, --ubatch-values CSV    physical ubatch-size values to test
                             default: 256,512,1024,2048
  -r, --repetitions N        llama-bench repetitions per test
                             default: 3
  -s, --service NAME         docker compose service to run
                             default: test
  -o, --output-dir DIR       write raw CSV and summaries here
                             default: ./tuning-results/YYYYMMDD_HHMMSS
  -h, --help                 show this help

If no extra llama-bench args are provided after "--", this script uses:
  -hf lmstudio-community/gemma-3-1B-it-qat-GGUF:Q4_0
  -ngl 99 -fa 1 -ctk f16 -ctv f16 -p 512 -n 128

Managed by this script:
  -b / --batch-size
  -ub / --ubatch-size
  -r / --repetitions
  -o / --output

Examples:
  ./tune-batch.sh

  ./tune-batch.sh -b 1024,2048,4096 -u 256,512,1024 -- \
    -hf lmstudio-community/gemma-3-1B-it-qat-GGUF:Q4_0 \
    -ngl 99 -fa 1 -ctk f16 -ctv f16 -p 512 -n 128
EOF
}

die() {
    echo "Error: $*" >&2
    exit 1
}

ensure_supported_extra_args() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            -b|--batch-size|-ub|--ubatch-size|-r|--repetitions|-o|--output)
                die "do not pass $arg after --; this script manages it"
                ;;
        esac
    done
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--batch-values)
            [[ $# -ge 2 ]] || die "$1 requires a value"
            BATCH_VALUES="$2"
            shift 2
            ;;
        -u|--ubatch-values)
            [[ $# -ge 2 ]] || die "$1 requires a value"
            UBATCH_VALUES="$2"
            shift 2
            ;;
        -r|--repetitions)
            [[ $# -ge 2 ]] || die "$1 requires a value"
            REPETITIONS="$2"
            shift 2
            ;;
        -s|--service)
            [[ $# -ge 2 ]] || die "$1 requires a value"
            SERVICE_NAME="$2"
            shift 2
            ;;
        -o|--output-dir)
            [[ $# -ge 2 ]] || die "$1 requires a value"
            OUTPUT_DIR="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        --)
            shift
            BENCH_ARGS=("$@")
            break
            ;;
        *)
            die "unknown option: $1"
            ;;
    esac
done

if [[ ${#BENCH_ARGS[@]} -eq 0 ]]; then
    BENCH_ARGS=("${DEFAULT_BENCH_ARGS[@]}")
else
    ensure_supported_extra_args "${BENCH_ARGS[@]}"
fi

if [[ -z "$OUTPUT_DIR" ]]; then
    OUTPUT_DIR="$BASE_DIR/tuning-results/$(date +"%Y%m%d_%H%M%S")"
fi

mkdir -p "$OUTPUT_DIR"

RAW_CSV="$OUTPUT_DIR/raw.csv"
SUMMARY_TSV="$OUTPUT_DIR/summary.tsv"
RECOMMENDATIONS_TXT="$OUTPUT_DIR/recommendations.txt"
TMP_SUMMARY="$OUTPUT_DIR/.summary.unsorted.tsv"

CMD=(
    docker compose run --rm
    --entrypoint /app/llama-bench
    "$SERVICE_NAME"
    "${BENCH_ARGS[@]}"
    -r "$REPETITIONS"
    -b "$BATCH_VALUES"
    -ub "$UBATCH_VALUES"
    -o csv
)

echo "Running batch sweep..."
echo "Service: $SERVICE_NAME"
echo "Batch values: $BATCH_VALUES"
echo "Ubatch values: $UBATCH_VALUES"
echo "Repetitions: $REPETITIONS"
echo "Extra llama-bench args: ${BENCH_ARGS[*]}"
echo "Output directory: $OUTPUT_DIR"

"${CMD[@]}" >"$RAW_CSV"

awk -F',' '
function unquote(v) {
    gsub(/^"|"$/, "", v)
    return v
}

NR == 1 {
    for (i = 1; i <= NF; i++) {
        name = unquote($i)
        idx[name] = i
    }

    required["n_batch"] = 1
    required["n_ubatch"] = 1
    required["n_prompt"] = 1
    required["n_gen"] = 1
    required["avg_ts"] = 1

    for (name in required) {
        if (!(name in idx)) {
            printf("missing expected CSV column: %s\n", name) > "/dev/stderr"
            exit 1
        }
    }

    next
}

{
    for (i = 1; i <= NF; i++) {
        $i = unquote($i)
    }

    key = $(idx["n_batch"]) SUBSEP $(idx["n_ubatch"])
    keys[key] = 1

    if ($(idx["n_prompt"]) + 0 > 0 && $(idx["n_gen"]) + 0 == 0) {
        pp_sum[key] += $(idx["avg_ts"]) + 0
        pp_count[key]++
    }

    if ($(idx["n_prompt"]) + 0 == 0 && $(idx["n_gen"]) + 0 > 0) {
        tg_sum[key] += $(idx["avg_ts"]) + 0
        tg_count[key]++
    }
}

END {
    print "n_batch\tn_ubatch\tavg_pp_tps\tavg_tg_tps\tbalanced_score"

    for (key in keys) {
        pp = pp_count[key] ? pp_sum[key] / pp_count[key] : 0
        tg = tg_count[key] ? tg_sum[key] / tg_count[key] : 0

        pp_avg[key] = pp
        tg_avg[key] = tg

        if (pp > max_pp) {
            max_pp = pp
        }

        if (tg > max_tg) {
            max_tg = tg
        }
    }

    for (key in keys) {
        split(key, parts, SUBSEP)
        pp = pp_avg[key]
        tg = tg_avg[key]

        pp_ratio = max_pp > 0 ? pp / max_pp : 0
        tg_ratio = max_tg > 0 ? tg / max_tg : 0

        if (pp > 0 && tg > 0 && (pp_ratio + tg_ratio) > 0) {
            score = 2 * pp_ratio * tg_ratio / (pp_ratio + tg_ratio)
        } else {
            score = pp_ratio + tg_ratio
        }

        printf "%s\t%s\t%.2f\t%.2f\t%.4f\n", parts[1], parts[2], pp, tg, score
    }
}
' "$RAW_CSV" >"$TMP_SUMMARY"

{
    head -n 1 "$TMP_SUMMARY"
    tail -n +2 "$TMP_SUMMARY" | LC_ALL=C sort -t $'\t' -k5,5nr -k3,3nr -k4,4nr -k1,1n -k2,2n
} >"$SUMMARY_TSV"

rm -f "$TMP_SUMMARY"

best_balanced_line="$(sed -n '2p' "$SUMMARY_TSV")"
best_pp_line="$(tail -n +2 "$SUMMARY_TSV" | LC_ALL=C sort -t $'\t' -k3,3nr -k4,4nr -k1,1n -k2,2n | head -n 1)"
best_tg_line="$(tail -n +2 "$SUMMARY_TSV" | LC_ALL=C sort -t $'\t' -k4,4nr -k3,3nr -k1,1n -k2,2n | head -n 1)"

[[ -n "$best_balanced_line" ]] || die "no sweep results were parsed from $RAW_CSV"

IFS=$'\t' read -r best_bal_b best_bal_ub best_bal_pp best_bal_tg best_bal_score <<<"$best_balanced_line"
IFS=$'\t' read -r best_pp_b best_pp_ub best_pp_pp best_pp_tg best_pp_score <<<"$best_pp_line"
IFS=$'\t' read -r best_tg_b best_tg_ub best_tg_pp best_tg_tg best_tg_score <<<"$best_tg_line"

cat >"$RECOMMENDATIONS_TXT" <<EOF
Best balanced:
  -b $best_bal_b -ub $best_bal_ub
  avg_pp_tps=$best_bal_pp
  avg_tg_tps=$best_bal_tg
  balanced_score=$best_bal_score

Best prompt throughput:
  -b $best_pp_b -ub $best_pp_ub
  avg_pp_tps=$best_pp_pp
  avg_tg_tps=$best_pp_tg
  balanced_score=$best_pp_score

Best generation throughput:
  -b $best_tg_b -ub $best_tg_ub
  avg_pp_tps=$best_tg_pp
  avg_tg_tps=$best_tg_tg
  balanced_score=$best_tg_score
EOF

echo
echo "Recommendations"
cat "$RECOMMENDATIONS_TXT"
echo
echo "Saved files:"
echo "  raw CSV: $RAW_CSV"
echo "  summary: $SUMMARY_TSV"
echo "  recommendations: $RECOMMENDATIONS_TXT"
echo
echo "Top combinations by balanced score:"
column -t -s $'\t' "$SUMMARY_TSV"
echo
echo "Validation tip:"
echo "  Use the balanced pick first in llama-server with --fit off, then re-check the top 1-2 PP/TG picks on your real workload."
