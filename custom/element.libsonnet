// observ-viz element veneer (hand-written).
// Elements are defined once (as a map name -> PanelKind) and referenced by name
// from layouts. This is the heart of the v2 "panels-as-elements" model.
{
  // panel(name, panelObj) yields a single-entry elements map.
  panel(name, panelObj): { [name]: panelObj },

  // ref(name) is an ElementReference used by layout items.
  ref(name): { kind: 'ElementReference', name: name },

  // libraryPanel(name, uid) references a shared library panel.
  libraryPanel(name, uid): {
    [name]: { kind: 'LibraryPanel', spec: { libraryPanel: { name: name, uid: uid } } },
  },

  // fromPairs([{name, panel}, ...]) builds an elements map from a list.
  fromPairs(pairs): { [p.name]: p.panel for p in pairs },
}
