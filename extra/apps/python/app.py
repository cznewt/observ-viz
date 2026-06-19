import sys
import time
import gc

from prometheus_client import start_http_server, Counter

# Counter for HTTP requests (incremented by the background loop).
HTTP_REQUESTS_TOTAL = Counter(
    "http_requests_total", "Total number of HTTP requests"
)


def log(level: str, msg: str, **fields):
    parts = [f'level={level}', f'msg="{msg}"']
    for key, value in fields.items():
        parts.append(f"{key}={value}")
    print(" ".join(parts), flush=True)


def work_loop():
    """Background loop: allocate + free memory (to trigger GC), bump the
    counter, and emit a log line every ~1-2s."""
    iteration = 0
    while True:
        iteration += 1

        # Allocate a chunk of memory and drop the reference so the GC has
        # something to collect.
        scratch = [object() for _ in range(50_000)]
        del scratch
        gc.collect()

        HTTP_REQUESTS_TOTAL.inc()
        log("info", "tick", iter=iteration)

        time.sleep(1.5)


def main():
    # Starts an HTTP server on port 8080 serving /metrics. The default
    # registry already includes the Python runtime collectors:
    # python_gc_collections_total, python_gc_objects_collected_total,
    # process_cpu_seconds_total, process_resident_memory_bytes,
    # process_open_fds.
    start_http_server(8080)
    log("info", "server started", port=8080)

    work_loop()


if __name__ == "__main__":
    main()
