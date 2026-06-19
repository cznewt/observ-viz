// observ-viz grid helpers (hand-written veneer).
// Adapts grafonnet's makeGrid/wrapPanels math to the v2 GridLayout model, where
// a placed panel is a GridLayoutItem carrying an ElementReference (by name) plus
// x/y/width/height — instead of a v1 panel with an inline gridPos.
{
  local gridWidth = 24,

  // wrapItems lays out a list of element NAMES left-to-right, wrapping to a new
  // row when the running x exceeds the 24-column grid. Returns GridLayoutItem
  // specs. width should divide 24 (e.g. 6, 8, 12) to avoid right-edge gaps.
  wrapItems(names, width=12, height=8, startY=0)::
    local n = std.length(names);
    local perRow = std.max(1, std.floor(gridWidth / width));
    [
      {
        kind: 'GridLayoutItem',
        spec: {
          x: (i % perRow) * width,
          y: startY + std.floor(i / perRow) * height,
          width: width,
          height: height,
          element: { kind: 'ElementReference', name: names[i] },
        },
      }
      for i in std.range(0, n - 1)
    ],

  // item builds a single explicitly-placed GridLayoutItem from an element name.
  item(name, x, y, width, height):: {
    kind: 'GridLayoutItem',
    spec: {
      x: x,
      y: y,
      width: width,
      height: height,
      element: { kind: 'ElementReference', name: name },
    },
  },
}
