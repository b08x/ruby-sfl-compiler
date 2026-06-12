#!/usr/bin/env python3
"""Export a directed call graph from graphify-out/graph.json."""

import json
import sys
from pathlib import Path
from collections import Counter


def shorten_path(p: str) -> str:
    p = p.replace("lib/sfl/compiler/", "")
    p = p.replace("lib/sfl/", "")
    p = p.replace("lib/", "")
    p = p.replace("scripts/sfl_analysis/templates/", "scripts/")
    return p


HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Call Graph — SFL Compiler</title>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0d1117; color: #c9d1d9; overflow: hidden; }
h1 { font-size: 18px; padding: 16px 24px 0; font-weight: 600; position: absolute; z-index: 10; }
p { font-size: 13px; padding: 4px 24px 12px; color: #8b949e; position: absolute; z-index: 10; }
svg { display: block; width: 100vw; height: 100vh; }
.link { fill: none; stroke-opacity: 0.4; }
.link:hover { stroke-opacity: 0.9; }
.node circle { cursor: pointer; stroke: #0d1117; stroke-width: 1.5px; }
.node text { font-size: 10px; fill: #c9d1d9; pointer-events: none; }
.node.dimmed circle { opacity: 0.15; }
.node.dimmed text { opacity: 0.15; }
.link.dimmed { stroke-opacity: 0.05; }
.node.highlighted circle { stroke: #f0f6fc; stroke-width: 2.5px; }
.node.highlighted text { font-weight: 600; }
.link.highlighted { stroke-opacity: 1; stroke-width: 2.5px; }
#tooltip {
  position: absolute; background: #161b22; border: 1px solid #30363d;
  border-radius: 6px; padding: 10px 14px; font-size: 12px;
  pointer-events: none; opacity: 0; transition: opacity 0.15s;
  max-width: 400px; z-index: 100; line-height: 1.5;
}
#tooltip .tt-name { font-weight: 600; color: #58a6ff; }
#tooltip .tt-community { color: #8b949e; font-size: 11px; }
#tooltip .tt-section { margin-top: 6px; color: #c9d1d9; }
#tooltip .tt-section strong { color: #f0f6fc; }
#legend { position: absolute; bottom: 16px; right: 24px; font-size: 11px; z-index: 10; }
#legend div { display: flex; align-items: center; gap: 6px; margin-bottom: 3px; }
#legend span { display: inline-block; width: 12px; height: 12px; border-radius: 2px; }
#controls { position: absolute; bottom: 16px; left: 24px; font-size: 11px; z-index: 10; color: #8b949e; }
</style>
</head>
<body>
<h1>Call Graph — SFL Compiler</h1>
<p>__SUMMARY__</p>
<div id="legend"></div>
<div id="controls">Scroll to zoom · Drag to pan · Click node to pin · Hover for detail</div>
<div id="tooltip"></div>
<svg></svg>
<script>
const data = __GRAPH_JSON__;
const tooltipData = __TOOLTIP_JSON__;

const width = window.innerWidth;
const height = window.innerHeight;

const svg = d3.select("svg")
  .attr("viewBox", [0, 0, width, height]);

// Arrow marker
svg.append("defs").selectAll("marker")
  .data(["arrow"])
  .join("marker")
    .attr("id", "arrow")
    .attr("viewBox", "0 -5 10 10")
    .attr("refX", 20)
    .attr("refY", 0)
    .attr("markerWidth", 6)
    .attr("markerHeight", 6)
    .attr("orient", "auto")
  .append("path")
    .attr("d", "M0,-5L10,0L0,5")
    .attr("fill", "#555");

const g = svg.append("g");

// Zoom
const zoom = d3.zoom()
  .scaleExtent([0.1, 8])
  .on("zoom", e => g.attr("transform", e.transform));
svg.call(zoom);

// Force simulation
const simulation = d3.forceSimulation(data.nodes)
  .force("link", d3.forceLink(data.links).id(d => d.id).distance(120))
  .force("charge", d3.forceManyBody().strength(-300))
  .force("center", d3.forceCenter(width / 2, height / 2))
  .force("x", d3.forceX(width / 2).strength(0.05))
  .force("y", d3.forceY(height / 2).strength(0.05))
  .force("collision", d3.forceCollide().radius(30));

// Draw links
const link = g.append("g")
  .selectAll(".link")
  .data(data.links)
  .join("path")
    .attr("class", "link")
    .attr("stroke", "#555")
    .attr("stroke-width", d => Math.max(1, d.weight || 1))
    .attr("marker-end", "url(#arrow)");

// Draw nodes
const node = g.append("g")
  .selectAll(".node")
  .data(data.nodes)
  .join("g")
    .attr("class", "node")
    .call(d3.drag()
      .on("start", dragStarted)
      .on("drag", dragged)
      .on("end", dragEnded));

node.append("circle")
  .attr("r", d => Math.max(5, Math.min(15, (d.degree || 1) * 2)))
  .attr("fill", d => d.color);

node.append("text")
  .attr("dx", d => Math.max(6, Math.min(15, (d.degree || 1) * 2)) + 4)
  .attr("dy", "0.35em")
  .text(d => d.name);

// Tooltip
const tooltip = d3.select("#tooltip");

function showTooltip(event, d) {
  const info = tooltipData[d.name] || {};
  const callers = Object.entries(info.callers || {}).map(([k,v]) => `<li>${k} (${v})</li>`).join("");
  const callees = Object.entries(info.callees || {}).map(([k,v]) => `<li>${k} (${v})</li>`).join("");
  tooltip.html(`
    <div class="tt-name">${d.name}</div>
    <div class="tt-community">${d.community}</div>
    <div class="tt-section" style="font-size:11px;color:#8b949e">${d.fullPath}</div>
    ${callers ? `<div class="tt-section"><strong>Called by:</strong><ul style="margin:4px 0 0 16px">${callers}</ul></div>` : ""}
    ${callees ? `<div class="tt-section"><strong>Calls:</strong><ul style="margin:4px 0 0 16px">${callees}</ul></div>` : ""}
  `).style("opacity", 1);
}

function moveTooltip(event) {
  tooltip.style("left", (event.pageX + 12) + "px").style("top", (event.pageY - 10) + "px");
}

function hideTooltip() { tooltip.style("opacity", 0); }

// Hover highlight
node.on("mouseenter", (event, d) => {
  const connected = new Set();
  connected.add(d.id);
  data.links.forEach(l => {
    const sid = typeof l.source === "object" ? l.source.id : l.source;
    const tid = typeof l.target === "object" ? l.target.id : l.target;
    if (sid === d.id) connected.add(tid);
    if (tid === d.id) connected.add(sid);
  });

  node.classed("dimmed", n => !connected.has(n.id));
  node.classed("highlighted", n => n.id === d.id);
  link.classed("dimmed", l => {
    const sid = typeof l.source === "object" ? l.source.id : l.source;
    const tid = typeof l.target === "object" ? l.target.id : l.target;
    return sid !== d.id && tid !== d.id;
  });
  link.classed("highlighted", l => {
    const sid = typeof l.source === "object" ? l.source.id : l.source;
    const tid = typeof l.target === "object" ? l.target.id : l.target;
    return sid === d.id || tid === d.id;
  });

  showTooltip(event, d);
})
.on("mousemove", moveTooltip)
.on("mouseleave", () => {
  node.classed("dimmed", false).classed("highlighted", false);
  link.classed("dimmed", false).classed("highlighted", false);
  hideTooltip();
});

// Click to pin
let pinned = null;
node.on("click", (event, d) => {
  event.stopPropagation();
  if (pinned === d.id) {
    pinned = null;
    node.classed("dimmed", false).classed("highlighted", false);
    link.classed("dimmed", false).classed("highlighted", false);
  } else {
    pinned = d.id;
    const connected = new Set();
    connected.add(d.id);
    data.links.forEach(l => {
      const sid = typeof l.source === "object" ? l.source.id : l.source;
      const tid = typeof l.target === "object" ? l.target.id : l.target;
      if (sid === d.id) connected.add(tid);
      if (tid === d.id) connected.add(sid);
    });
    node.classed("dimmed", n => !connected.has(n.id));
    node.classed("highlighted", n => n.id === d.id);
    link.classed("dimmed", l => {
      const sid = typeof l.source === "object" ? l.source.id : l.source;
      const tid = typeof l.target === "object" ? l.target.id : l.target;
      return sid !== d.id && tid !== d.id;
    });
    link.classed("highlighted", l => {
      const sid = typeof l.source === "object" ? l.source.id : l.source;
      const tid = typeof l.target === "object" ? l.target.id : l.target;
      return sid === d.id || tid === d.id;
    });
  }
});

svg.on("click", () => {
  pinned = null;
  node.classed("dimmed", false).classed("highlighted", false);
  link.classed("dimmed", false).classed("highlighted", false);
});

// Tick
simulation.on("tick", () => {
  link.attr("d", d => {
    const dx = d.target.x - d.source.x;
    const dy = d.target.y - d.source.y;
    const dr = Math.sqrt(dx * dx + dy * dy) * 1.5;
    return `M${d.source.x},${d.source.y}A${dr},${dr} 0 0,1 ${d.target.x},${d.target.y}`;
  });
  node.attr("transform", d => `translate(${d.x},${d.y})`);
});

// Drag
function dragStarted(event) {
  if (!event.active) simulation.alphaTarget(0.3).restart();
  event.subject.fx = event.subject.x;
  event.subject.fy = event.subject.y;
}
function dragged(event) {
  event.subject.fx = event.x;
  event.subject.fy = event.y;
}
function dragEnded(event) {
  if (!event.active) simulation.alphaTarget(0);
  if (!pinned) { event.subject.fx = null; event.subject.fy = null; }
}

// Legend
const communities = [...new Set(data.nodes.map(d => d.community))].sort();
const legend = d3.select("#legend");
communities.forEach(c => {
  const color = data.nodes.find(d => d.community === c)?.color || "#999";
  legend.append("div").html(`<span style="background:${color}"></span>${c}`);
});

// Fit to screen after stabilization
simulation.on("end", () => {
  const bounds = g.node().getBBox();
  const fullWidth = bounds.width + 100;
  const fullHeight = bounds.height + 100;
  const midX = bounds.x + bounds.width / 2;
  const midY = bounds.y + bounds.height / 2;
  const scale = Math.min(width / fullWidth, height / fullHeight) * 0.85;
  const transform = d3.zoomIdentity
    .translate(width / 2 - midX * scale, height / 2 - midY * scale)
    .scale(scale);
  svg.transition().duration(500).call(zoom.transform, transform);
});
</script>
</body>
</html>"""


def build_directed_html(graph_path: str, output_path: str) -> None:
    data = json.loads(Path(graph_path).read_text())
    nodes_raw = data.get("nodes", [])
    links_raw = data.get("links", data.get("edges", []))

    node_map = {n["id"]: n for n in nodes_raw}

    call_links = [
        l for l in links_raw
        if l.get("relation") in ("calls", "invokes", "called_by")
    ]

    if not call_links:
        print("No call edges found in graph.")
        sys.exit(1)

    # Filter self-loops
    filtered = []
    for l in call_links:
        src_id = l.get("source", "")
        tgt_id = l.get("target", "")
        src_file = node_map.get(src_id, {}).get("source_file", "")
        tgt_file = node_map.get(tgt_id, {}).get("source_file", "")
        if src_file != tgt_file:
            filtered.append(l)

    if not filtered:
        print("No cross-file call edges found.")
        sys.exit(1)

    # Collect unique nodes involved in calls
    involved_ids = set()
    for l in filtered:
        involved_ids.add(l["source"])
        involved_ids.add(l["target"])

    COMMUNITY_COLORS = [
        "#1f77b4", "#ff7f0e", "#2ca02c", "#d62728", "#9467bd",
        "#8c564b", "#e377c2", "#7f7f7f", "#bcbd22", "#17becf",
        "#aec7e8", "#ffbb78", "#98df8a", "#ff9896", "#c5b0d5",
        "#c49c94", "#f7b6d2", "#c7c7c7", "#dbdb8d", "#9edae5",
    ]

    labels_path = Path(graph_path).parent / ".graphify_labels.json"
    community_labels = {}
    if labels_path.exists():
        raw = json.loads(labels_path.read_text())
        community_labels = {int(k): v for k, v in raw.items()}

    # Degree count
    degree = Counter()
    for l in filtered:
        degree[l["source"]] += 1
        degree[l["target"]] += 1

    # Build graph nodes
    graph_nodes = []
    for nid in involved_ids:
        n = node_map.get(nid, {})
        c = n.get("community")
        color = COMMUNITY_COLORS[int(c) % len(COMMUNITY_COLORS)] if c is not None else "#999"
        graph_nodes.append({
            "id": nid,
            "name": n.get("label", nid),
            "fullPath": n.get("source_file", ""),
            "community": community_labels.get(int(c), f"Community {c}") if c is not None else "unknown",
            "color": color,
            "degree": degree.get(nid, 1),
        })

    # Build graph links (use id references)
    graph_links = []
    for l in filtered:
        weight = l.get("weight", 1)
        graph_links.append({
            "source": l["source"],
            "target": l["target"],
            "relation": l.get("relation", ""),
            "confidence": l.get("confidence", ""),
            "weight": weight,
        })

    # Tooltip data
    tooltip_data = {}
    for nid in involved_ids:
        n = node_map.get(nid, {})
        short = shorten_path(n.get("source_file", ""))
        callers = Counter()
        callees = Counter()
        for l in filtered:
            if l["target"] == nid:
                callers[shorten_path(node_map.get(l["source"], {}).get("label", l["source"]))] += 1
            if l["source"] == nid:
                callees[shorten_path(node_map.get(l["target"], {}).get("label", l["target"]))] += 1
        c = n.get("community")
        tooltip_data[n.get("label", nid)] = {
            "fullPath": n.get("source_file", ""),
            "community": community_labels.get(int(c), f"Community {c}") if c is not None else "unknown",
            "callers": dict(callers),
            "callees": dict(callees),
        }

    graph_json = json.dumps({"nodes": graph_nodes, "links": graph_links})
    tooltip_json = json.dumps(tooltip_data)
    summary = f"{len(graph_nodes)} functions · {len(graph_links)} call edges · scroll to zoom · click to pin"

    html = HTML_TEMPLATE
    html = html.replace("__GRAPH_JSON__", graph_json)
    html = html.replace("__TOOLTIP_JSON__", tooltip_json)
    html = html.replace("__SUMMARY__", summary)

    Path(output_path).write_text(html)
    print(f"callgraph.html written — {len(graph_nodes)} nodes, {len(graph_links)} edges")
    print(f"  Open: file://{Path(output_path).resolve()}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <graph.json> <output.html>")
        sys.exit(1)
    build_directed_html(sys.argv[1], sys.argv[2])
