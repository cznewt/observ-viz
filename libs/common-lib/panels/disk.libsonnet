// observ-viz common-lib disk panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/disk.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;
local st = g.panel.stat;
local tb = g.panel.table;

// disk time series base: like generic but with a very light fill so
// crowded read/write series stay readable.
local diskTs(title, targets, description) =
  generic.timeSeries(title, targets, description)
  + ts.custom.withFillOpacity(1);

// render write/out series below the zero axis (read +, write -).
local negateOut(regexp='/write|written/') =
  ts.withFieldConfigDefaults({ custom+: { axisLabel: 'write(-) | read(+)', axisCenteredZero: true } })
  + ts.standardOptions.withOverrides([
    {
      matcher: { id: 'byRegexp', options: regexp },
      properties: [{ id: 'custom.transform', value: 'negative-Y' }],
    },
  ]);

{
  // ---- timeSeries -------------------------------------------------------
  // base: disk time series (light fill).
  timeSeries(title='', targets=[], description=''):
    diskTs(title, targets, description),

  // available: free disk space in bytes.
  available(title='Disk space available', targets=[], description=''):
    diskTs(title, targets, description)
    + ts.standardOptions.withUnit('bytes')
    + ts.standardOptions.withMin(0),

  // usage: used disk space in bytes.
  usage(title='Disk space used', targets=[], description=''):
    diskTs(title, targets, description)
    + ts.standardOptions.withUnit('bytes'),

  // usagePercent: used disk space as a 0-100% gauge view.
  usagePercent(title='Disk space used, %', targets=[], description=''):
    diskTs(title, targets, description)
    + ts.standardOptions.withUnit('percent')
    + ts.standardOptions.withDecimals(1)
    + ts.withFieldConfigDefaults({ color+: { mode: 'continuous-BlYlRd' } })
    + ts.custom.withGradientMode('scheme')
    + ts.standardOptions.withMax(100)
    + ts.standardOptions.withMin(0),

  // ioBytesPerSec: disk read/write throughput in bytes/sec.
  ioBytesPerSec(title='Disk reads/writes', targets=[], description='Disk read/writes in bytes per second.'):
    diskTs(title, targets, description)
    + ts.standardOptions.withUnit('Bps')
    + ts.standardOptions.withOverrides([
      {
        matcher: { id: 'byRegexp', options: '/time|used|busy|util/' },
        properties: [
          { id: 'unit', value: 'percent' },
          { id: 'custom.drawStyle', value: 'points' },
          { id: 'custom.axisSoftMax', value: 100 },
        ],
      },
    ]),

  // iops: I/O operations per second (read +, write -).
  iops(title='Disk I/O', targets=[], description=''):
    diskTs(title, targets, description)
    + ts.standardOptions.withUnit('iops')
    + negateOut(),

  // ioQueue: average IO queue depth (read +, write -).
  ioQueue(title='Disk IO queue', targets=[], description='Disk average IO queue.'):
    diskTs(title, targets, description)
    + negateOut(),

  // ioWaitTime: average request service time in seconds (read +, write -).
  ioWaitTime(title='Disk average wait time', targets=[], description=''):
    diskTs(title, targets, description)
    + ts.standardOptions.withUnit('s')
    + negateOut(),

  // ---- stat -------------------------------------------------------------
  // base: plain disk stat (generic styling).
  stat(title='', targets=[], description=''):
    generic.stat(title, targets, description),

  // total: total disk size (info stat, bytes).
  total(title='Disk total', targets=[], description=''):
    generic.statInfo(title, targets, description)
    + st.standardOptions.withUnit('bytes'),

  // ---- table ------------------------------------------------------------
  // base: plain disk table (generic styling).
  table(title='', targets=[], description=''):
    generic.table(title, targets, description),

  // usage: disk space usage table, bytes-formatted.
  usageTable(title='Disk space usage', targets=[], description=''):
    generic.table(title, targets, description)
    + tb.standardOptions.withUnit('bytes'),
}
