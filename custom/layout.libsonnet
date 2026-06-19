// observ-viz layout veneer (hand-written).
// First-class v2 layouts. Every item/row/tab takes an element NAME (string) and
// wraps it in an ElementReference — never a panel object — enforcing the
// define-once / reference-by-name model. Layouts nest (rows/tabs hold layouts).
local grid = import 'custom/util/grid.libsonnet';

{
  ref(name): { kind: 'ElementReference', name: name },

  grid: {
    new(): { kind: 'GridLayout', spec: { items: [] } },
    item(name, x, y, width, height): grid.item(name, x, y, width, height),
    withItems(items): { spec+: { items: items } },
    withItemsMixin(items): { spec+: { items+: items } },
    // auto-place a list of element names left-to-right, wrapping at 24 columns.
    fromElements(names, width=12, height=8, startY=0):
      { kind: 'GridLayout', spec: { items: grid.wrapItems(names, width, height, startY) } },
  },

  rows: {
    new(): { kind: 'RowsLayout', spec: { rows: [] } },
    row(title, layout, collapse=false):
      { kind: 'RowsLayoutRow', spec: { title: title, collapse: collapse, layout: layout } },
    withRows(rows): { spec+: { rows: rows } },
    withRowsMixin(rows): { spec+: { rows+: rows } },
  },

  autoGrid: {
    new(maxColumnCount=3, columnWidthMode='standard', rowHeightMode='standard', fillScreen=false): {
      kind: 'AutoGridLayout',
      spec: {
        maxColumnCount: maxColumnCount,
        columnWidthMode: columnWidthMode,
        rowHeightMode: rowHeightMode,
        fillScreen: fillScreen,
        items: [],
      },
    },
    item(name): { kind: 'AutoGridLayoutItem', spec: { element: { kind: 'ElementReference', name: name } } },
    withItems(names): {
      spec+: {
        items: [
          { kind: 'AutoGridLayoutItem', spec: { element: { kind: 'ElementReference', name: n } } }
          for n in names
        ],
      },
    },
  },

  tabs: {
    new(): { kind: 'TabsLayout', spec: { tabs: [] } },
    tab(title, layout): { kind: 'TabsLayoutTab', spec: { title: title, layout: layout } },
    withTabs(tabs): { spec+: { tabs: tabs } },
    withTabsMixin(tabs): { spec+: { tabs+: tabs } },
  },
}
