// observ-viz reference — shared helper.
local g = import 'g.libsonnet';
{
  // place a board in a Grafana folder (with a readable title) and tag it.
  place(dashboard, folder, tags):
    dashboard
    + g.dashboard.withFolder(folder.uid, folder.title)
    + g.dashboard.withTagsMixin(tags),
}
