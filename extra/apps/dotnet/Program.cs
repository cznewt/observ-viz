using Prometheus;
using Prometheus.DotNetRuntime;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

// Expose default .NET runtime metrics (GC, threadpool, exceptions, etc.)
// so dotnet_* series are available at /metrics.
DotNetRuntimeStatsBuilder.Default().StartCollecting();

var requests = Metrics.CreateCounter(
    "http_requests_total",
    "Total number of background-loop iterations.");

// Prometheus scrape endpoint at /metrics.
app.MapMetrics();

app.MapGet("/", () => "observ-viz dotnet sample\n");

// Background loop: allocate + free memory (triggers GC), increment a counter,
// and emit a log line to STDOUT every ~1-2s.
_ = Task.Run(async () =>
{
    var rnd = new Random();
    long iter = 0;
    while (true)
    {
        iter++;

        // Allocate then drop a chunk of memory so the GC has work to do.
        var junk = new byte[1024 * 1024];
        rnd.NextBytes(junk);
        junk = Array.Empty<byte>();

        requests.Inc();

        Console.WriteLine($"level=info msg=\"tick\" iter={iter}");

        await Task.Delay(1500);
    }
});

app.Run();
