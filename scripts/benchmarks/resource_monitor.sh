#!/usr/bin/env bash
#
# resource_monitor.sh
#
# Captures docker stats + host resource usage while a GRACE benchmark run
# is in flight, then flags the likely culprits behind a latency blowup:
#   - per-container CPU / memory saturation
#   - host-level load / iowait / swap pressure
#   - leftover tc/netem latency rules on the wsserver container
#   - memgraph running with expensive logging (e.g. --log-level=TRACE)
#
# Usage:
#   ./resource_monitor.sh start [interval_sec] [outdir]     # begin background sampling
#   ./resource_monitor.sh stop  [outdir]                     # stop sampling, take final snapshot
#   ./resource_monitor.sh analyze [outdir]                   # print a report from captured logs
#   ./resource_monitor.sh run <duration_sec> [interval_sec] [outdir]
#                                                             # start, sleep, stop, analyze in one shot
#
# Typical use around Grace1and3Replicas.sh:
#   ./resource_monitor.sh start 2 ./resource_logs/1replica
#   python3 Deployment.py up $DIST_CONF -v
#   ... run YCSB ...
#   ./resource_monitor.sh stop ./resource_logs/1replica
#   ./resource_monitor.sh analyze ./resource_logs/1replica

set -uo pipefail

INTERVAL_DEFAULT=2
OUTDIR_DEFAULT="./resource_logs"
PIDFILE=".resource_monitor.pids"

# Only track containers relevant to the GRACE stack
CONTAINER_FILTER='memgraph[0-9]+|neo4j[0-9]+|Grace[0-9]+|wsserver|preload[0-9]+|lab[0-9]+'

timestamp() { date +"%Y-%m-%dT%H:%M:%S%z"; }

sample_docker_stats() {
    local outdir=$1 interval=$2
    local f="$outdir/docker_stats.csv"
    echo "timestamp,container,cpu_pct,mem_usage,mem_limit,mem_pct,net_io,block_io,pids" > "$f"
    while true; do
        docker stats --no-stream --format \
          '{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}},{{.PIDs}}' \
          2>/dev/null | while IFS=, read -r name cpu memusage memp net block pids; do
            [[ "$name" =~ $CONTAINER_FILTER ]] || continue
            mem_usage=$(echo "$memusage" | cut -d/ -f1 | xargs)
            mem_limit=$(echo "$memusage" | cut -d/ -f2 | xargs)
            echo "$(timestamp),$name,$cpu,$mem_usage,$mem_limit,$memp,$net,$block,$pids" >> "$f"
        done
        sleep "$interval"
    done
}

sample_host() {
    local outdir=$1 interval=$2
    local f="$outdir/host_stats.csv"
    echo "timestamp,load1,load5,load15,cpu_idle_pct,mem_used_pct,swap_used_mb,iowait_pct" > "$f"
    while true; do
        local load load1 load5 load15
        load=$(uptime | awk -F'load average: ' '{print $2}' | tr -d ',')
        read -r load1 load5 load15 <<< "$load"

        # vmstat: r b swpd free buff cache si so bi bo in cs us sy id wa st
        local vmstat_line idle iowait
        vmstat_line=$(vmstat 1 2 2>/dev/null | tail -1)
        idle=$(echo "$vmstat_line" | awk '{print $15}')
        iowait=$(echo "$vmstat_line" | awk '{print $16}')

        local mem_total mem_avail mem_used_pct
        mem_total=$(awk '/MemTotal/{print $2}' /proc/meminfo)
        mem_avail=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
        mem_used_pct=$(awk -v t="$mem_total" -v a="$mem_avail" 'BEGIN{printf "%.1f", (t-a)/t*100}')

        local swap_used_kb swap_used_mb
        swap_used_kb=$(awk '/SwapTotal/{t=$2} /SwapFree/{f=$2} END{print t-f}' /proc/meminfo)
        swap_used_mb=$((swap_used_kb / 1024))

        echo "$(timestamp),$load1,$load5,$load15,$idle,$mem_used_pct,$swap_used_mb,$iowait" >> "$f"
        sleep "$interval"
    done
}

snapshot_checks() {
    local outdir=$1 label=$2
    {
        echo "=== $label @ $(timestamp) ==="
        echo "--- tc qdisc on wsserver (leftover simulated latency?) ---"
        docker exec wsserver tc qdisc show 2>&1 || echo "(wsserver not running or tc unavailable)"
        echo
        echo "--- memgraph container command / log level ---"
        for c in $(docker ps --format '{{.Names}}' 2>/dev/null | grep -E '^memgraph[0-9]+$'); do
            cmd=$(docker inspect --format '{{join .Config.Cmd " "}}' "$c" 2>/dev/null)
            echo "[$c] command: $cmd"
        done
        echo
        echo "--- running containers ---"
        docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' 2>/dev/null
        echo
    } >> "$outdir/diagnostic_snapshots.log"
}

start_monitor() {
    local interval=${1:-$INTERVAL_DEFAULT}
    local outdir=${2:-$OUTDIR_DEFAULT}
    : > "$PIDFILE"

    snapshot_checks "$outdir" "START"

    sample_docker_stats "$outdir" "$interval" &
    echo "$!" >> "$PIDFILE"

    sample_host "$outdir" "$interval" &
    echo "$!" >> "$PIDFILE"

    echo "Monitoring started. interval=${interval}s outdir=$outdir"
    echo "PIDs: $(tr '\n' ' ' < "$PIDFILE")"
}

stop_monitor() {
    local outdir=${1:-$OUTDIR_DEFAULT}
    if [[ ! -f "$PIDFILE" ]]; then
        echo "No PID file found ($PIDFILE). Nothing to stop."
        return 1
    fi
    while read -r pid; do
        kill "$pid" 2>/dev/null
    done < "$PIDFILE"
    rm -f "$PIDFILE"
    snapshot_checks "$outdir" "STOP"
    echo "Monitoring stopped."
}

analyze() {
    local outdir=${1:-$OUTDIR_DEFAULT}
    local ds="$outdir/docker_stats.csv"
    local hs="$outdir/host_stats.csv"
    local sn="$outdir/diagnostic_snapshots.log"

    echo "================= RESOURCE ANALYSIS: $outdir ================="

    if [[ -f "$ds" ]]; then
        echo
        echo "--- Per-container CPU/mem peaks ---"
        awk -F, 'NR>1 {
            cpu=$3; gsub(/%/,"",cpu);
            mem=$6; gsub(/%/,"",mem);
            if (cpu+0 > maxcpu[$2]) maxcpu[$2]=cpu+0;
            if (mem+0 > maxmem[$2]) maxmem[$2]=mem+0;
        }
        END {
            for (c in maxcpu) printf "%-15s max_cpu=%.1f%%  max_mem=%.1f%%\n", c, maxcpu[c], maxmem[c];
        }' "$ds" | sort

        echo
        echo "--- Flags: container CPU > 90% or mem > 85% ---"
        awk -F, 'NR>1 {
            cpu=$3; gsub(/%/,"",cpu);
            mem=$6; gsub(/%/,"",mem);
            if (cpu+0 > 90) print $1, $2, "CPU spike:", $3;
            if (mem+0 > 85) print $1, $2, "MEM spike:", $6;
        }' "$ds"
    else
        echo "(no docker_stats.csv found in $outdir)"
    fi

    if [[ -f "$hs" ]]; then
        echo
        echo "--- Host load / iowait / swap peaks ---"
        awk -F, 'NR>1 {
            if ($2+0 > maxload) maxload=$2+0;
            if ($8+0 > maxiowait) maxiowait=$8+0;
            if ($6+0 > maxmemp) maxmemp=$6+0;
            if ($7+0 > maxswap) maxswap=$7+0;
        }
        END {
            printf "max_load1=%.2f  max_iowait=%.1f%%  max_mem_used=%.1f%%  max_swap_mb=%d\n", maxload, maxiowait, maxmemp, maxswap
        }' "$hs"

        echo
        echo "--- Flags: iowait > 20% or swap in use > 100MB ---"
        awk -F, 'NR>1 {
            if ($8+0 > 20) print $1, "high iowait:", $8"%";
            if ($7+0 > 100) print $1, "swap in use:", $7"MB";
        }' "$hs"
    else
        echo "(no host_stats.csv found in $outdir)"
    fi

    if [[ -f "$sn" ]]; then
        echo
        echo "--- Diagnostic checks from start/stop snapshots ---"
        if grep -q "netem" "$sn"; then
            echo "[!] tc/netem rule found on wsserver -- leftover simulated latency may be in effect:"
            grep -A2 "netem" "$sn"
        else
            echo "[ok] No netem/tc latency rules detected on wsserver."
        fi

        echo
        if grep -qi "log-level=trace\|log-level TRACE\|TRACE" "$sn"; then
            echo "[!] memgraph appears to be running with verbose (TRACE) logging:"
            grep -i "command:" "$sn"
        else
            echo "[ok] No TRACE-level memgraph logging detected in snapshot."
        fi
    else
        echo "(no diagnostic_snapshots.log found in $outdir)"
    fi

    echo "================================================================"
}

usage() {
    cat <<EOF
Usage:
  $0 start [interval_sec] [outdir]     Start background sampling
  $0 stop  [outdir]                    Stop sampling, take a final snapshot
  $0 analyze [outdir]                  Print a report from captured logs
  $0 run <duration_sec> [interval_sec] [outdir]
                                        Start, sleep for duration, stop, analyze
EOF
}

cmd=${1:-}
case "$cmd" in
    start)
        start_monitor "${2:-}" "${3:-}"
        ;;
    stop)
        stop_monitor "${2:-}"
        ;;
    analyze)
        analyze "${2:-}"
        ;;
    run)
        duration=${2:?duration_sec required}
        interval=${3:-$INTERVAL_DEFAULT}
        outdir=${4:-$OUTDIR_DEFAULT}
        start_monitor "$interval" "$outdir"
        echo "Sampling for ${duration}s..."
        sleep "$duration"
        stop_monitor "$outdir"
        analyze "$outdir"
        ;;
    *)
        usage
        exit 1
        ;;
esac
