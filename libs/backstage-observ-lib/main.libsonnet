// observ-viz Backstage pack (hand-written).
// Catalog context for a service, read from Backstage through the Grafana
// Infinity datasource (yesoreyeram-infinity-datasource, pointed at the
// Backstage backend): who owns it, lifecycle, type, system, description,
// relations (dependsOn / dependencyOf / partOf / APIs), links and annotations.
//
// Two ways to read the catalog:
//   api: 'rest'     GET /api/catalog/entities?filter=kind=..,metadata.name=..
//                   the full entity: relations, links, description, tags.
//   api: 'graphql'  POST /api/graphql  { catalog { list { ... } } }
//                   the legacy Backstage GraphQL plugin: name, annotations,
//                   labels and for components type/lifecycle/owner only — no
//                   relations, links or description in that schema.
// Query URLs are relative to the Infinity datasource base URL (the Backstage
// backend); set backendUrl for an absolute one. List selectors are wrapped in
// $append(.., []) so a missing entity yields an empty table, not an error.
//
//   g.libs.backstage.component('${backstage_datasource}', 'grafana')
//     -> { stats: {..}, tables: {..} } element maps for a service board
//   g.libs.backstage.new({}).grafana.dashboard   -> the catalog overview board
local dashboard = (import 'gen/observ-viz-v2beta1/dashboard.libsonnet') + (import 'custom/dashboard.libsonnet');
local layout = import 'custom/layout.libsonnet';
local grid = import 'custom/util/grid.libsonnet';
local panel = import 'custom/panel.libsonnet';
local query = import 'custom/query.libsonnet';
local variable =
  local gv = import 'gen/observ-viz-v2beta1/variable/main.libsonnet';
  local cv = import 'custom/variable.libsonnet';
  { datasource: gv.datasource + cv.datasource };

local dsType = 'yesoreyeram-infinity-datasource';
local col(selector, text) = { selector: selector, text: text, type: 'string' };
local infinity(datasource, spec) = query.base(dsType, { source: 'url', format: 'table', parser: 'backend' } + spec) + query.withDatasource(datasource);
local rest(datasource, url, root, columns) = infinity(datasource, { type: 'json', url: url, root_selector: root, columns: columns });
local graphql(datasource, url, gql, root, columns) = infinity(datasource, {
  type: 'graphql',
  url: url,
  root_selector: root,
  columns: columns,
  url_options: { method: 'POST', body_type: 'graphql', body_graphql_query: gql, body_graphql_variables: '{}' },
});
// a stat tile that shows a string field of the first row.
local labelStat(title, target, field, desc) =
  panel.stat.new(title)
  + panel.withDescription(desc)
  + panel.stat.withTargets([target])
  + panel.stat.withOptions({ reduceOptions: { values: true, fields: '/^' + field + '$/' }, colorMode: 'none', graphMode: 'none', textMode: 'value' });
local table(title, target, desc) =
  panel.table.new(title) + panel.withDescription(desc) + panel.table.withTargets([target]);
local gqlList = '{ catalog { list { kind metadata { name annotations labels } spec { ... on ComponentEntitySpec { type lifecycle owner } } } } }';

{
  // for embedding: catalog element maps for one entity.
  component(datasource, name, kind='component', namespace='default', api='rest', backendUrl='', uiUrl='', prefix='')::
    local entity = backendUrl + '/api/catalog/entities?filter=kind=' + kind + ',metadata.namespace=' + namespace + ',metadata.name=' + name;
    local gqlUrl = backendUrl + '/api/graphql';
    // GraphQL kinds are capitalised (Component), REST filters are not.
    local gqlKind = std.asciiUpper(std.substr(kind, 0, 1)) + std.substr(kind, 1, std.length(kind));
    local gqlRoot = "data.catalog.list[kind='" + gqlKind + "' and metadata.name='" + name + "']";
    local overview =
      if api == 'graphql' then
        graphql(datasource, gqlUrl, gqlList, gqlRoot, [col('metadata.name', 'name'), col('kind', 'kind'), col('spec.type', 'type'), col('spec.lifecycle', 'lifecycle'), col('spec.owner', 'owner')])
      else
        rest(datasource, entity, '', [col('metadata.name', 'name'), col('metadata.title', 'title'), col('kind', 'kind'), col('spec.type', 'type'), col('spec.lifecycle', 'lifecycle'), col('spec.owner', 'owner'), col('spec.system', 'system'), col('metadata.description', 'description'), col("$join(metadata.tags, ', ')", 'tags'), col("$join(spec.dependsOn, ', ')", 'dependsOn')]);
    local annotations =
      if api == 'graphql' then
        graphql(datasource, gqlUrl, gqlList, '$append(' + gqlRoot + ".metadata.annotations ~> $each(function($v, $k) {{'key': $k, 'value': $v}}), [])", [col('key', 'annotation'), col('value', 'value')])
      else
        rest(datasource, entity, "$append(metadata.annotations ~> $each(function($v, $k) {{'key': $k, 'value': $v}}), [])", [col('key', 'annotation'), col('value', 'value')]);
    local uiLink = if uiUrl != '' then uiUrl + '/catalog/' + namespace + '/' + kind + '/' + name else '';
    {
      stats: {
        [prefix + 'b01_type']: labelStat('Type', overview, 'type', 'Component type from the catalog (service, library, website...).'),
        [prefix + 'b02_lifecycle']: labelStat('Lifecycle', overview, 'lifecycle', 'Lifecycle stage from the catalog (experimental, production, deprecated).'),
        [prefix + 'b03_owner']: labelStat('Owner', overview, 'owner', 'Owning team or user, the entity to page for this service.'),
      } + (if api == 'graphql' then {} else {
             [prefix + 'b04_system']: labelStat('System', overview, 'system', 'System this component is part of.'),
           }),
      tables: {
        [prefix + 'b11_component']: table('Component', overview, 'The catalog entry as Backstage stores it: name, title, description, tags and declared dependencies.'),
      } + (if api == 'graphql' then {} else {
             [prefix + 'b12_relations']: table('Relations', rest(datasource, entity, '$append(relations, [])', [col('type', 'relation'), col('target.kind', 'kind'), col('target.name', 'name')]), 'Catalog relations: what this component depends on, what depends on it, the system it is part of, the APIs it provides or consumes, and its owner.'),
             [prefix + 'b13_links']: table('Links', rest(datasource, entity, '$append(metadata.links, [])', [col('title', 'title'), col('url', 'url')]), 'Links declared on the catalog entry (runbooks, repos, dashboards, docs).')
                                     + panel.withOverrides([{ matcher: { id: 'byName', options: 'url' }, properties: [{ id: 'links', value: [{ title: 'Open', url: '${__data.fields.url}', targetBlank: true }] }] }]),
           }) + {
        [prefix + 'b14_annotations']: table('Annotations', annotations, 'Catalog annotations: source location, TechDocs, Kubernetes namespace, dashboard selectors and other integrations keyed by this entity.'),
      } + (if uiLink != '' then {
             [prefix + 'b15_backstage']: panel.text.new('Backstage')
                                         + panel.withDescription('The entity in Backstage.')
                                         + panel.text.withOptions({ mode: 'markdown', content: '[Open **' + name + '** in Backstage ↗](' + uiLink + ')  ·  [TechDocs ↗](' + uiUrl + '/docs/' + namespace + '/' + kind + '/' + name + ')' }),
           } else {}),
    },

  // the catalog overview board: every component with its owner, lifecycle,
  // type and system, plus the systems and APIs.
  new(config={}):
    local cfg = {
      uid: 'observ-viz-backstage',
      dashboardTitle: 'Backstage catalog',
      dashboardTags: ['backstage', 'catalog', 'app-level'],
      description: 'The Backstage software catalog read through the Infinity datasource: components with owner, lifecycle, type and system; systems; APIs.',
      datasource: '${backstage_datasource}',
      backendUrl: '',
      api: 'rest',
      // the shared tabbed board: Overview + a tab per signal group
      tabbed: true,
      folderUid: 'components-cicd',
      folderTitle: 'CI/CD',
      folderParentUid: 'components',
      folderParentTitle: 'Components',
    } + config;
    local list(kind) = cfg.backendUrl + '/api/catalog/entities?filter=kind=' + kind;
    local components =
      if cfg.api == 'graphql' then
        graphql(cfg.datasource, cfg.backendUrl + '/api/graphql', gqlList, "data.catalog.list[kind='Component']", [col('metadata.name', 'name'), col('spec.type', 'type'), col('spec.lifecycle', 'lifecycle'), col('spec.owner', 'owner')])
      else
        rest(cfg.datasource, list('component'), '', [col('metadata.name', 'name'), col('metadata.title', 'title'), col('spec.type', 'type'), col('spec.lifecycle', 'lifecycle'), col('spec.owner', 'owner'), col('spec.system', 'system'), col('metadata.description', 'description')]);
    local systems = rest(cfg.datasource, list('system'), '', [col('metadata.name', 'name'), col('spec.owner', 'owner'), col('spec.domain', 'domain'), col('metadata.description', 'description')]);
    local apis = rest(cfg.datasource, list('api'), '', [col('metadata.name', 'name'), col('spec.type', 'type'), col('spec.lifecycle', 'lifecycle'), col('spec.owner', 'owner'), col('spec.system', 'system')]);
    local elements = {
      components: table('Components', components, 'Every component in the catalog with its owner, lifecycle, type and system.'),
      systems: table('Systems', systems, 'Systems in the catalog.'),
      apis: table('APIs', apis, 'APIs in the catalog.'),
    };
    local board =
      dashboard.new(cfg.dashboardTitle)
      + dashboard.withUid(cfg.uid)
      + dashboard.withDescription(cfg.description)
      + dashboard.withTags(cfg.dashboardTags)
      + dashboard.withFolder(cfg.folderUid, cfg.folderTitle, cfg.folderParentUid, cfg.folderParentTitle)
      + dashboard.withVariables([variable.datasource.new('backstage_datasource', dsType) + { spec+: { label: 'Backstage' } }])
      + dashboard.withElements(elements)
      + dashboard.withLayout(layout.rows.new() + layout.rows.withRows([
        layout.rows.row('Components', layout.grid.new() + layout.grid.withItems([grid.item('components', 0, 0, 24, 14)])),
        layout.rows.row('Systems & APIs', layout.grid.new() + layout.grid.withItems([grid.item('systems', 0, 0, 12, 10), grid.item('apis', 12, 0, 12, 10)])),
      ]));
    {
      config: cfg,
      signals: {},
      grafana: { elements: elements, dashboard: board, dashboards: { [cfg.uid + '.json']: board } },
      prometheus: { alerts: [], rules: [] },
      asMonitoringMixin():: { grafanaDashboards+:: { [cfg.uid + '.json']: board.toSpec() } },
    },
}
