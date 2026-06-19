// observ-viz query veneer (hand-written, self-contained).
// Assembles the full g.query namespace: generic base(dsKind, spec), shared
// setters, and typed per-datasource namespaces merging generated spec setters
// (gen/query/*) with a new() constructor.
// v2beta1: the datasource lives inside the DataQuery as { name: <uid> }.
local qbase = import 'custom/queryBase.libsonnet';
local gq = import 'gen/observ-viz-v2beta1/query/main.libsonnet';

local withDs(uid) = { spec+: { query+: { datasource: { name: uid } } } };

local shared = {
  withRefId(value): { spec+: { refId: value } },
  withHidden(value=true): { spec+: { hidden: value } },
  // datasource by uid (a concrete uid or a '${var}' template reference).
  withDatasource(uid): { spec+: { query+: { datasource: { name: uid } } } },
  withDatasourceFromVariable(name): { spec+: { query+: { datasource: { name: '${' + name + '}' } } } },
};

shared + {
  // generic escape hatch: works for ANY datasource by name.
  base(dsKind, spec): qbase(dsKind, spec),

  prometheus: gq.prometheus + shared + { new(datasource, expr): qbase('prometheus', { expr: expr }) + withDs(datasource) },
  loki: gq.loki + shared + { new(datasource, expr): qbase('loki', { expr: expr }) + withDs(datasource) },
}
