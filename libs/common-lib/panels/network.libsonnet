// observ-viz common-lib network panel presets.
// Ported from grafana/jsonnet-libs common-lib/common/panels/network.
local g = import 'g.libsonnet';
local generic = import 'libs/common-lib/panels/generic.libsonnet';
local ts = g.panel.timeSeries;
local sh = g.panel.statusHistory;

// network time series base: packets/sec by default, 1 decimal.
local netTs(title, targets, description, noValue='No packets') =
  generic.timeSeries(title, targets, description)
  + ts.standardOptions.withDecimals(1)
  + ts.standardOptions.withUnit('pps')
  + ts.standardOptions.withNoValue(noValue);

{
  // ---- timeSeries -------------------------------------------------------
  // base: packets-per-second network time series.
  timeSeries(title='', targets=[], description=''):
    netTs(title, targets, description),

  // traffic: throughput in bits/sec.
  traffic(title='Network traffic', targets=[], description='Network traffic (bits per sec) measures data transmitted and received.'):
    netTs(title, targets, description, 'No traffic')
    + ts.standardOptions.withUnit('bps'),

  // packets: total network packet count.
  packets(title='Network packets', targets=[], description=''):
    netTs(title, targets, description),

  // errors: network errors over time.
  errors(title='Network errors', targets=[], description=''):
    netTs(title, targets, description, 'No errors'),

  // dropped: dropped packets over time.
  dropped(title='Dropped packets', targets=[], description=''):
    netTs(title, targets, description, 'No dropped packets'),

  // broadcast: broadcast packets over time.
  broadcast(title='Broadcast packets', targets=[], description='Packets sent from one source to all network nodes.'):
    netTs(title, targets, description, 'No broadcast packets'),

  // multicast: multicast packets over time.
  multicast(title='Multicast packets', targets=[], description=''):
    netTs(title, targets, description, 'No multicast packets'),

  // unicast: unicast packets over time.
  unicast(title='Unicast packets', targets=[], description='Packets sent from one source to a single destination.'):
    netTs(title, targets, description, 'No unicast packets'),

  // ---- statusHistory ----------------------------------------------------
  // interfaceStatus: up/down state with green/red value mappings.
  interfaceStatus(title='Interface status', targets=[], description='Interfaces statuses'):
    generic.statusHistory(title, targets, description)
    + sh.withFieldConfigDefaults({ color+: { mode: 'fixed' } })
    + sh.withOptions({ showValue: 'never' })
    + sh.withMappings([{
      type: 'value',
      options: {
        '0': { text: 'Down', color: '#ff7383', index: 0 },
        '1': { text: 'Up', color: '#73bf69', index: 1 },
      },
    }]),
}
