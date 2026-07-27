// observ-viz Syncthing pack (hand-written).
// Built for Syncthing's built-in Prometheus endpoint (/metrics, syncthing_*).
// Usage:
//   g.libs.applications.syncthing.new({ selector: 'job="syncthing"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-syncthing',
      dashboardTitle: 'Syncthing',
      dashboardTags: ['syncthing', 'sync', 'app-level'],
      links: [
        { title: 'Environment', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: false, tooltip: 'Environment-level boards', tags: ['env-level'] },
        { title: 'Cluster boards', type: 'dashboards', icon: 'dashboard', url: '', keepTime: true, targetBlank: false, asDropdown: true, includeVars: true, tooltip: 'Boards for this cluster', tags: ['cluster-level'] },
      ],
      docTabs: true,
      datasource: '${datasource}',
      selector: 'job=~"$job", instance=~"$instance"',
      varMetric: 'syncthing_connections_active',
      varLabels: ['instance'],
      ruleSelector: '',
    } + config;

    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      // connections_active is per remote device (1/0), config_device_info maps
      // the device id to its name
      devicesOnline: sig('Devices connected', 'sum(syncthing_connections_active{%(queriesSelector)s})', 'short', 'connected'),
      devicesKnown: sig('Devices known', 'count(syncthing_config_device_info{%(queriesSelector)s})', 'short', 'known'),
      foldersKnown: sig('Folders', 'count(syncthing_config_folder_info{%(queriesSelector)s})', 'short', 'folders'),
      syncedBytes: sig('Data synced', 'sum(syncthing_model_folder_summary{scope="local", type="bytes", %(queriesSelector)s})', 'bytes', 'local data'),
      connectionsActive: sig('Active connections', 'syncthing_connections_active{%(queriesSelector)s} * on (instance, device) group_left(name) syncthing_config_device_info{%(queriesSelector)s}', 'short', '{{instance}} / {{name}}'),
      sentBytes: sig('Sent', 'rate(syncthing_protocol_sent_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      recvBytes: sig('Received', 'rate(syncthing_protocol_recv_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      folderState: sig('Folder state', 'syncthing_model_folder_state{%(queriesSelector)s}', 'short', '{{instance}} / {{folder}}'),
      folderProcessed: sig('Folder processed', 'rate(syncthing_model_folder_processed_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{folder}}'),
      conflicts: sig('Conflicts', 'sum by (instance, folder) (rate(syncthing_model_folder_conflicts_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{instance}} / {{folder}}'),
      pullSeconds: sig('Pull time', 'rate(syncthing_model_folder_pull_seconds_total{%(queriesSelector)s}[$__rate_interval])', 's', '{{instance}} / {{folder}}'),
      scanSeconds: sig('Scan time', 'rate(syncthing_model_folder_scan_seconds_total{%(queriesSelector)s}[$__rate_interval])', 's', '{{instance}} / {{folder}}'),
      scannedItems: sig('Items scanned', 'sum by (instance) (rate(syncthing_scanner_scanned_items_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
      hashedBytes: sig('Hashed', 'sum by (instance) (rate(syncthing_scanner_hashed_bytes_total{%(queriesSelector)s}[$__rate_interval]))', 'Bps'),
      fsOps: sig('Filesystem ops', 'sum by (instance, operation) (rate(syncthing_fs_operations_total{%(queriesSelector)s}[$__rate_interval]))', 'ops', '{{instance}} / {{operation}}'),
      events: sig('Events', 'sum by (instance) (rate(syncthing_events_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
    };

    // per-folder inventory: identity from config_folder_info, counts/bytes from
    // the local scope of folder_summary, joined on instance|folder
    local tq(expr) =
      query.prometheus.new(cfg.datasource, expr)
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } };
    local ov(regex, props) = { matcher: { id: 'byRegexp', options: regex }, properties: props };
    local jk = '"key", "|", "instance", "folder"';
    local sum(t, scope='local') =
      'sum by (key) (label_join(syncthing_model_folder_summary{scope="' + scope + '", type="' + t + '", ' + cfg.selector + '}, ' + jk + '))';
    local foldersTable =
      panel.table.new('Folders')
      + panel.table.withTargets([
        tq('label_join(syncthing_config_folder_info{' + cfg.selector + '}, ' + jk + ')'),  // A: identity
        tq(sum('bytes')),      // B
        tq(sum('files')),      // C
        tq(sum('directories')),  // D
        tq(sum('bytes', 'global')),  // E
        tq('sum by (key) (label_join(syncthing_model_folder_state{' + cfg.selector + '}, ' + jk + '))'),  // F: state
      ])
      + panel.table.withTransformations([
        { id: 'labelsToFields' },
        { id: 'filterFieldsByName', options: { include: { names: [
          'key', 'instance', 'folder', 'label', 'path', 'type', 'paused',
          'Value #B', 'Value #C', 'Value #D', 'Value #E', 'Value #F',
        ] } } },
        { id: 'seriesToColumns', options: { byField: 'key' } },
        { id: 'organize', options: {
          excludeByName: { key: true, 'Value #A': true, folder: true },
          indexByName: {
            instance: 0, label: 1, path: 2, type: 3, 'Value #F': 4, 'Value #C': 5,
            'Value #D': 6, 'Value #B': 7, 'Value #E': 8, paused: 9,
            key: 10, folder: 11, 'Value #A': 12,
          },
          renameByName: {
            instance: 'Host', label: 'Folder', path: 'Path', type: 'Mode',
            'Value #F': 'State', 'Value #C': 'Files', 'Value #D': 'Dirs',
            'Value #B': 'Local size', 'Value #E': 'Global size', paused: 'Paused',
          },
        } },
        { id: 'sortBy', options: { sort: [{ field: 'Host', desc: false }] } },
      ])
      + panel.table.withOverrides([
        ov('^Folder$', [{ id: 'custom.width', value: 190 }]),
        ov('^Path$', [{ id: 'custom.width', value: 220 }]),
        ov('^Mode$|^Paused$', [{ id: 'custom.width', value: 110 }]),
        ov('size$', [{ id: 'unit', value: 'bytes' }, { id: 'custom.width', value: 110 }]),
        ov('^Files$|^Dirs$', [{ id: 'custom.width', value: 90 }]),
        // syncthing FolderState: 0 idle, 1 scanning, 2 syncing, 3 error
        ov('^State$', [
          { id: 'custom.width', value: 110 },
          { id: 'mappings', value: [{ type: 'value', options: {
            '0': { text: 'idle', color: 'green' },
            '1': { text: 'scanning', color: 'blue' },
            '2': { text: 'syncing', color: 'orange' },
            '3': { text: 'error', color: 'red' },
          } }] },
          { id: 'custom.cellOptions', value: { type: 'color-text' } },
        ]),
      ]);

    pack.build(cfg, signals, [
      {
        title: 'Overview',
        width: 6,
        height: 5,
        elements: {
          a_devicesOnline: signals.devicesOnline.asStat('Devices connected'),
          b_devicesKnown: signals.devicesKnown.asStat('Devices known'),
          c_folders: signals.foldersKnown.asStat('Folders'),
          d_synced: signals.syncedBytes.asStat('Local data'),
        },
      },
      { title: 'Folders', width: 24, height: 10, elements: { foldersTable: foldersTable } },
      {
        title: 'Transfer',
        width: 12,
        height: 7,
        elements: {
          a_connections: signals.connectionsActive.asTimeSeries('Active connections'),
          b_recv: signals.recvBytes.asTimeSeries('Received'),
          c_sent: signals.sentBytes.asTimeSeries('Sent'),
          d_processed: signals.folderProcessed.asTimeSeries('Folder processed'),
        },
      },
      {
        title: 'Scanner & filesystem',
        width: 12,
        height: 7,
        elements: {
          a_hashed: signals.hashedBytes.asTimeSeries('Hashed'),
          b_scanned: signals.scannedItems.asTimeSeries('Items scanned/s'),
          c_scan: signals.scanSeconds.asTimeSeries('Scan time/s'),
          d_pull: signals.pullSeconds.asTimeSeries('Pull time/s'),
          e_fsops: signals.fsOps.asTimeSeries('Filesystem ops/s'),
          f_conflicts: signals.conflicts.asTimeSeries('Conflicts/s'),
        },
      },
    ], [
      alert.rule.group('syncthing', [
        alert.rule.new(
          'SyncthingFolderConflicts',
          'sum by (instance, folder) (rate(syncthing_model_folder_conflicts_total{' + cfg.ruleSelector + '}[5m])) > 0',
          '15m',
          'warning',
          {},
          {
            summary: 'Syncthing folder has conflicts.',
            description: 'Syncthing folder {{ $labels.folder }} on {{ $labels.instance }} is generating sync conflicts.',
          }
        ),
      ]),
    ]),
}
