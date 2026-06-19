// observ-viz resource finalization helpers (hand-written veneer).
// These operate on the v2 dashboard envelope produced by custom/dashboard.libsonnet.
{
  // refId letters A..Z then AA.. style fallback (index based).
  refIdFor(i)::
    if i < 26 then std.char(65 + i)
    else std.char(65 + (i / 26) - 1) + std.char(65 + (i % 26)),

  // assignRefIds assigns a sequential refId to every query that has none
  // (its spec.refId == null), preserving any explicitly set refId.
  assignRefIds(targets):: [
    targets[i] {
      spec+: {
        refId:
          if std.objectHas(targets[i].spec, 'refId') && targets[i].spec.refId != null
          then targets[i].spec.refId
          else $.refIdFor(i),
      },
    }
    for i in std.range(0, std.length(targets) - 1)
  ],

  // assignElementIds stamps a deterministic integer spec.id on every Panel
  // element, ordered by sorted element name. LibraryPanel elements are left
  // untouched (they carry no spec.id).
  assignElementIds(elements)::
    local names = std.sort(std.objectFields(elements));
    {
      [names[i]]:
        if std.objectHas(elements[names[i]], 'kind') && elements[names[i]].kind == 'Panel'
        then elements[names[i]] { spec+: { id: i + 1 } }
        else elements[names[i]]
      for i in std.range(0, std.length(names) - 1)
    },

  // collectRefs walks a (possibly nested) layout and returns the flat list of
  // every ElementReference.name it points at. Used by structural tests.
  collectRefs(layout)::
    local k = layout.kind;
    if k == 'GridLayout' then
      [it.spec.element.name for it in layout.spec.items]
    else if k == 'AutoGridLayout' then
      [it.spec.element.name for it in layout.spec.items]
    else if k == 'RowsLayout' then
      std.flattenArrays([$.collectRefs(r.spec.layout) for r in layout.spec.rows])
    else if k == 'TabsLayout' then
      std.flattenArrays([$.collectRefs(t.spec.layout) for t in layout.spec.tabs])
    else [],
}
