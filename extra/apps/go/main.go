package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
	"time"

	"github.com/prometheus/client_golang/prometheus"
	"github.com/prometheus/client_golang/prometheus/promauto"
	"github.com/prometheus/client_golang/prometheus/promhttp"
)

var httpRequestsTotal = promauto.NewCounter(prometheus.CounterOpts{
	Name: "http_requests_total",
	Help: "Total number of HTTP requests processed by the background loop.",
})

func main() {
	logger := log.New(os.Stdout, "", 0)

	// The default registry already exposes Go runtime collectors:
	// go_goroutines, go_memstats_*, go_threads, go_gc_duration_seconds,
	// process_cpu_seconds_total, process_open_fds, etc.
	http.Handle("/metrics", promhttp.Handler())
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintln(w, "observ-viz sample-go: see /metrics for Prometheus metrics")
	})

	// Background loop: do a little work, increment a counter, log a line.
	go func() {
		iter := 0
		for {
			iter++

			// Allocate and free some memory so the GC has work to do.
			buf := make([]byte, 1<<20) // 1 MiB
			for i := range buf {
				buf[i] = byte(i)
			}
			_ = buf
			buf = nil

			httpRequestsTotal.Inc()
			logger.Printf("level=info msg=\"tick\" iter=%d", iter)

			time.Sleep(1500 * time.Millisecond)
		}
	}()

	logger.Printf("level=info msg=\"listening\" addr=\":8080\"")
	if err := http.ListenAndServe(":8080", nil); err != nil {
		logger.Fatalf("level=error msg=\"server failed\" err=%q", err)
	}
}
