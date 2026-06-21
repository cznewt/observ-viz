// observ-viz Syncthing pack (hand-written).
// Built for Syncthing's built-in Prometheus endpoint (/metrics, syncthing_*).
// Usage:
//   g.libs.applications.syncthing.new({ selector: 'job="syncthing"' }).grafana.dashboard
local pack = import 'libs/common-lib/pack.libsonnet';
local signal = import 'libs/common-lib/signal/main.libsonnet';
local alert = import 'libs/common-lib/alert/main.libsonnet';

{
  new(config={}):
    local cfg = {
      uid: 'observ-viz-syncthing',
      dashboardTitle: 'Syncthing',
      dashboardTags: ['syncthing', 'sync'],
      datasource: '${datasource}',
      selector: 'job=~"$job", instance=~"$instance"',
      varMetric: 'syncthing_connections_active',
      varLabels: ['instance'],
      ruleSelector: '',
    } + config;

    local sig(name, expr, unit, legend='{{instance}}') =
      signal.new(name, 'prometheus', cfg.datasource, expr, unit).filteringSelector(cfg.selector).withLegendFormat(legend);

    local signals = {
      connectionsActive: sig('Active connections', 'syncthing_connections_active{%(queriesSelector)s}', 'short', '{{instance}} / {{device}}'),
      sentBytes: sig('Sent', 'rate(syncthing_protocol_sent_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      recvBytes: sig('Received', 'rate(syncthing_protocol_recv_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{device}}'),
      folderState: sig('Folder state', 'syncthing_model_folder_state{%(queriesSelector)s}', 'short', '{{instance}} / {{folder}}'),
      folderProcessed: sig('Folder processed', 'rate(syncthing_model_folder_processed_bytes_total{%(queriesSelector)s}[$__rate_interval])', 'Bps', '{{instance}} / {{folder}}'),
      conflicts: sig('Conflicts', 'sum by (folder) (rate(syncthing_model_folder_conflicts_total{%(queriesSelector)s}[$__rate_interval]))', 'short', '{{folder}}'),
      filesUpdated: sig('Files updated', 'sum(rate(syncthing_db_files_updated_total{%(queriesSelector)s}[$__rate_interval]))', 'ops'),
    };

    pack.build(cfg, signals, [
      {
        title: 'Connections',
        width: 12,
        height: 7,
        elements: {
          connectionsActive: signals.connectionsActive.asTimeSeries('Active connections'),
          recvBytes: signals.recvBytes.asTimeSeries('Received'),
          sentBytes: signals.sentBytes.asTimeSeries('Sent'),
        },
      },
      {
        title: 'Folders',
        width: 12,
        height: 7,
        elements: {
          folderState: signals.folderState.asTable('Folder state'),
          folderProcessed: signals.folderProcessed.asTimeSeries('Folder processed'),
          conflicts: signals.conflicts.asTimeSeries('Conflicts/s'),
        },
      },
      {
        title: 'Database',
        width: 12,
        height: 7,
        elements: {
          filesUpdated: signals.filesUpdated.asTimeSeries('Files updated/s'),
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
