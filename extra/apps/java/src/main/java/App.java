import com.sun.net.httpserver.HttpExchange;
import com.sun.net.httpserver.HttpServer;
import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.binder.jvm.ClassLoaderMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmGcMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmMemoryMetrics;
import io.micrometer.core.instrument.binder.jvm.JvmThreadMetrics;
import io.micrometer.core.instrument.binder.system.ProcessorMetrics;
import io.micrometer.core.instrument.binder.system.UptimeMetrics;
import io.micrometer.prometheusmetrics.PrometheusConfig;
import io.micrometer.prometheusmetrics.PrometheusMeterRegistry;

import java.io.IOException;
import java.io.OutputStream;
import java.net.InetSocketAddress;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Executors;
import java.util.concurrent.ThreadLocalRandom;

public final class App {

    private static final int PORT = 8080;

    public static void main(String[] args) throws IOException {
        PrometheusMeterRegistry registry =
                new PrometheusMeterRegistry(PrometheusConfig.DEFAULT);

        // Default JVM runtime collectors (jvm_*, process_*, system_* metrics).
        new JvmMemoryMetrics().bindTo(registry);
        new JvmGcMetrics().bindTo(registry);
        new JvmThreadMetrics().bindTo(registry);
        new ClassLoaderMetrics().bindTo(registry);
        new ProcessorMetrics().bindTo(registry);
        new UptimeMetrics().bindTo(registry);

        Counter httpRequests = Counter.builder("http_requests_total")
                .description("Total number of HTTP requests handled")
                .register(registry);

        HttpServer server = HttpServer.create(new InetSocketAddress(PORT), 0);
        server.setExecutor(Executors.newFixedThreadPool(4));

        server.createContext("/metrics", exchange -> {
            byte[] body = registry.scrape().getBytes(StandardCharsets.UTF_8);
            send(exchange, 200, "text/plain; version=0.0.4; charset=utf-8", body);
        });

        server.createContext("/", exchange -> {
            byte[] body = "observ-viz sample java app\n".getBytes(StandardCharsets.UTF_8);
            send(exchange, 200, "text/plain; charset=utf-8", body);
        });

        server.start();
        System.out.println("level=info msg=\"server started\" port=" + PORT);

        Thread worker = new Thread(() -> backgroundLoop(httpRequests), "worker");
        worker.setDaemon(true);
        worker.start();
    }

    private static void backgroundLoop(Counter httpRequests) {
        long iter = 0;
        while (true) {
            iter++;

            // Allocate then free some memory so the GC has work to do.
            List<byte[]> junk = new ArrayList<>();
            int blocks = ThreadLocalRandom.current().nextInt(20, 60);
            for (int i = 0; i < blocks; i++) {
                junk.add(new byte[64 * 1024]);
            }
            int sum = 0;
            for (byte[] block : junk) {
                sum += block.length;
            }
            junk.clear();
            junk = null;

            httpRequests.increment();

            System.out.println("level=info msg=\"tick\" iter=" + iter
                    + " allocated_bytes=" + sum);

            try {
                Thread.sleep(ThreadLocalRandom.current().nextInt(1000, 2000));
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                return;
            }
        }
    }

    private static void send(HttpExchange exchange, int status, String contentType,
                             byte[] body) throws IOException {
        exchange.getResponseHeaders().set("Content-Type", contentType);
        exchange.sendResponseHeaders(status, body.length);
        try (OutputStream os = exchange.getResponseBody()) {
            os.write(body);
        }
    }

    private App() {
    }
}
