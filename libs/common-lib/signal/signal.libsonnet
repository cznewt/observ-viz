// observ-viz lean v2-native signal (hand-written).
// A signal couples a logical metric (datasource + expr template + unit) to its
// renderings as v2 elements (asTimeSeries/asStat/asTable) and as a query
// (asTarget). Prometheus/Loki get selector-injection + aggregation; any other
// datasource kind passes the expr through unchanged (generic).
//
// expr templates may use %(queriesSelector)s and %(filteringSelector)s tokens.
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';

{
  new(name, type, datasource, expr, unit='short'):: {
    local this = self,
    _name:: name,
    _type:: type,  // 'prometheus' | 'loki' | <generic ds kind>
    _datasource:: datasource,
    _expr:: expr,
    _unit:: unit,
    _description:: '',
    _legend:: null,
    _filteringSelector:: '',
    _groupLabels:: [],
    _instanceLabels:: [],
    _aggLevel:: 'none',  // 'none' | 'group' | 'instance'

    // --- builder modifiers (return a modified signal) ---
    withExpr(e):: self { _expr:: e },
    withUnit(u):: self { _unit:: u },
    withDescription(d):: self { _description:: d },
    withLegendFormat(l):: self { _legend:: l },
    withDatasource(ds):: self { _datasource:: ds },
    filteringSelector(s):: self { _filteringSelector:: s },
    groupLabels(l):: self { _groupLabels:: l },
    instanceLabels(l):: self { _instanceLabels:: l },
    aggLevel(a):: self { _aggLevel:: a },

    // --- expression assembly ---
    _selector()::
      std.join(', ', std.prune([if this._filteringSelector != '' then this._filteringSelector else null])),
    _templated()::
      this._expr % {
        queriesSelector: this._selector(),
        filteringSelector: this._filteringSelector,
      },
    _aggExpr(e)::
      if this._type == 'prometheus' && this._aggLevel != 'none' then
        local labels =
          if this._aggLevel == 'instance' then this._groupLabels + this._instanceLabels
          else this._groupLabels;
        'sum by (' + std.join(', ', labels) + ') (' + e + ')'
      else e,
    _effectiveExpr():: this._aggExpr(this._templated()),

    // --- renderings ---
    asTarget()::
      local e = this._effectiveExpr();
      local base =
        if this._type == 'loki' then query.loki.new(this._datasource, e)
        else if this._type == 'prometheus' then query.prometheus.new(this._datasource, e)
        else query.base(this._type, { expr: e }) + query.withDatasource(this._datasource);
      base + (if this._legend != null then { spec+: { query+: { spec+: { legendFormat: this._legend } } } } else {}),

    asTableTarget()::
      this.asTarget()
      + { spec+: { query+: { spec+: { instant: true, range: false, format: 'table' } } } },

    asTimeSeries(title=this._name)::
      panel.timeSeries.new(title)
      + panel.timeSeries.withTargets([this.asTarget()])
      + panel.timeSeries.standardOptions.withUnit(this._unit),

    asStat(title=this._name)::
      panel.stat.new(title)
      + panel.stat.withTargets([this.asTarget()])
      + panel.stat.standardOptions.withUnit(this._unit),

    asTable(title=this._name)::
      panel.table.new(title)
      + panel.table.withTargets([this.asTableTarget()])
      + panel.table.standardOptions.withUnit(this._unit),

    // a Prometheus recording rule { record, expr } derived from this signal.
    // `selector` replaces the dashboard filteringSelector (rules can't use
    // dashboard $vars); `$__rate_interval` is replaced with `interval`.
    asRecordingRule(record, selector='', interval='5m'):: {
      record: record,
      expr:
        local raw = std.strReplace(
          this._aggExpr(this._expr % { queriesSelector: selector, filteringSelector: selector }),
          '$__rate_interval',
          interval
        );
        // tidy the empty-selector case: '{mode="idle",}' -> '{mode="idle"}', '{}' -> ''
        std.strReplace(std.strReplace(raw, ',}', '}'), '{}', ''),
    },
  },
}
