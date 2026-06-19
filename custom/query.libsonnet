// observ-viz query veneer (hand-written, self-contained).
// Assembles the full g.query namespace: generic base(dsKind, spec), shared
// setters, and typed per-datasource namespaces merging generated spec setters
// (gen/query/*) with a new() constructor.
local qbase = import 'custom/queryBase.libsonnet';
local gq = import 'gen/observ-viz-v2beta1/query/main.libsonnet';

local withDs(type, uid) = { spec+: { datasource: { type: type, uid: uid } } };

local shared = {
  withRefId(value): { spec+: { refId: value } },
  withHidden(value=true): { spec+: { hidden: value } },
  withDatasource(type, uid): { spec+: { datasource: { type: type, uid: uid } } },
  withDatasourceFromVariable(name): { spec+: { datasource: { uid: '${' + name + '}' } } },
};

shared + {
  // generic escape hatch: works for ANY datasource by name.
  base(dsKind, spec): qbase(dsKind, spec),

  prometheus: gq.prometheus + shared + { new(datasource, expr): qbase('prometheus', { expr: expr }) + withDs('prometheus', datasource) },
  loki: gq.loki + shared + { new(datasource, expr): qbase('loki', { expr: expr }) + withDs('loki', datasource) },
}
