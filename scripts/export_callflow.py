#!/usr/bin/env python3
"""Export a callflow Sankey diagram from graphify-out/graph.json."""

import json
import sys
from pathlib import Path
from collections import Counter, defaultdict


def shorten_path(p: str) -> str:
    """Shorten a file path for display."""
    p = p.replace("lib/sfl/compiler/", "")
    p = p.replace("lib/sfl/", "")
    p = p.replace("lib/", "")
    p = p.replace("scripts/sfl_analysis/templates/", "scripts/")
    return p


HTML_TEMPLATE = r"""<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Callflow — SFL Compiler</title>
<script src="https://cdn.jsdelivr.net/npm/d3@7"></script>
<script src="https://cdn.jsdelivr.net/npm/d3-sankey@0.12.3/dist/d3-sankey.min.js"></script>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: #0d1117; color: #c9d1d9; }
h1 { font-size: 18px; padding: 16px 24px 0; font-weight: 600; }
p { font-size: 13px; padding: 4px 24px 12px; color: #8b949e; }
svg { display: block; }
.sankey-node rect { cursor: pointer; }
.sankey-node text { font-size: 11px; fill: #c9d1d9; pointer-events: none; }
.sankey-link { fill: none; stroke-opacity: 0.3; }
.sankey-link:hover { stroke-opacity: 0.7; }
#tooltip {
  position: absolute; background: #161b22; border: 1px solid #30363d;
  border-radius: 6px; padding: 10px 14px; font-size: 12px;
  pointer-events: none; opacity: 0; transition: opacity 0.15s;
  max-width: 400px; z-index: 100; line-height: 1.5;
}
#tooltip .tt-file { font-weight: 600; color: #58a6ff; }
#tooltip .tt-community { color: #8b949e; font-size: 11px; }
#tooltip .tt-section { margin-top: 6px; color: #c9d1d9; }
#tooltip .tt-section strong { color: #f0f6fc; }
#legend { position: absolute; top: 16px; right: 24px; font-size: 11px; }
#legend div { display: flex; align-items: center; gap: 6px; margin-bottom: 3px; }
#legend span { display: inline-block; width: 12px; height: 12px; border-radius: 2px; }
</style>
</head>
<body>
<h1>Callflow — SFL Compiler</h1>
<p>__SUMMARY__</p>
<div id="legend"></div>
<div id="tooltip"></div>
<script>
const data = __SANKEY_JSON__;
const tooltipData = __TOOLTIP_JSON__;

if (typeof d3 === "undefined") {
  document.body.innerHTML += '<p style="color:red;padding:20px">Error: D3.js failed to load. Check your internet connection.</p>';
} else if (typeof d3.sankey === "undefined") {
  document.body.innerHTML += '<p style="color:red;padding:20px">Error: d3-sankey failed to load. d3.sankey is undefined. Check console.</p>';
  console.error("d3 version:", d3.version);
  console.error("d3.sankey:", d3.sankey);
} else {

const width = Math.max(960, data.nodes.length * 50);
const height = Math.max(600, data.links.length * 20 + 200);
const margin = { top: 10, right: 180, bottom: 10, left: 10 };

const svg = d3.select("body").append("svg")
  .attr("width", width + margin.left + margin.right)
  .attr("height", height + margin.top + margin.bottom)
  .append("g")
  .attr("transform", `translate(${margin.left},${margin.top})`);

const sankey = d3.sankey()
  .nodeId(d => d.index)
  .nodeWidth(15)
  .nodePadding(12)
  .nodeAlign(d3.sankeyJustify)
  .extent([[0, 0], [width, height]]);

const graph = sankey({
  nodes: data.nodes.map((d, i) => ({...d, index: i})),
  links: data.links.map(d => ({...d})),
});

// Draw links
const link = svg.append("g")
  .selectAll(".sankey-link")
  .data(graph.links)
  .join("path")
  .attr("class", "sankey-link")
  .attr("d", d3.sankeyLinkHorizontal())
  .attr("stroke-width", d => Math.max(1, d.width))
  .attr("stroke", d => d.source.color)
  .on("mouseenter", showLinkTooltip)
  .on("mousemove", moveTooltip)
  .on("mouseleave", hideTooltip);

// Draw nodes
const node = svg.append("g")
  .selectAll(".sankey-node")
  .data(graph.nodes)
  .join("g")
  .attr("class", "sankey-node")
  .attr("transform", d => `translate(${d.x0},${d.y0})`)
  .on("mouseenter", showNodeTooltip)
  .on("mousemove", moveTooltip)
  .on("mouseleave", hideTooltip);

node.append("rect")
  .attr("width", d => d.x1 - d.x0)
  .attr("height", d => Math.max(1, d.y1 - d.y0))
  .attr("fill", d => d.color)
  .attr("rx", 2);

node.append("text")
  .attr("x", d => d.x0 < width / 2 ? (d.x1 - d.x0) + 6 : -6)
  .attr("y", d => (d.y1 - d.y0) / 2)
  .attr("dy", "0.35em")
  .attr("text-anchor", d => d.x0 < width / 2 ? "start" : "end")
  .text(d => d.name);

// Tooltip
const tooltip = d3.select("#tooltip");

function showLinkTooltip(event, d) {
  const src = d.source;
  const tgt = d.target;
  tooltip.html(`
    <div class="tt-file">${src.name} → ${tgt.name}</div>
    <div class="tt-section"><strong>${d.value}</strong> call(s)</div>
    <div class="tt-community">${src.community} → ${tgt.community}</div>
  `).style("opacity", 1);
}

function showNodeTooltip(event, d) {
  const info = tooltipData[d.name] || {};
  const callers = Object.entries(info.callers || {}).map(([k,v]) => `<li>${k} (${v})</li>`).join("");
  const callees = Object.entries(info.callees || {}).map(([k,v]) => `<li>${k} (${v})</li>`).join("");
  tooltip.html(`
    <div class="tt-file">${d.name}</div>
    <div class="tt-community">${d.community}</div>
    ${callers ? `<div class="tt-section"><strong>Called by:</strong><ul>${callers}</ul></div>` : ""}
    ${callees ? `<div class="tt-section"><strong>Calls:</strong><ul>${callees}</ul></div>` : ""}
    <div class="tt-community" style="margin-top:4px">${info.fullPath}</div>
  `).style("opacity", 1);
}

function moveTooltip(event) {
  tooltip.style("left", (event.pageX + 12) + "px").style("top", (event.pageY - 10) + "px");
}

function hideTooltip() { tooltip.style("opacity", 0); }

// Legend
const communities = [...new Set(data.nodes.map(d => d.community))].sort();
const legend = d3.select("#legend");
communities.forEach(c => {
  const color = data.nodes.find(d => d.community === c)?.color || "#999";
  legend.append("div").html(`<span style="background:${color}"></span>${c}`);
});

} // end else (d3-sankey loaded)
</script>
</body>
</html>"""


def build_callflow_html(graph_path: str, output_path: str) -> None:
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

    file_flows = Counter()
    file_functions = defaultdict(lambda: {"callers": Counter(), "callees": Counter()})

    for link in call_links:
        src_id = link.get("source", link.get("from", ""))
        tgt_id = link.get("target", link.get("to", ""))

        src_node = node_map.get(src_id, {})
        tgt_node = node_map.get(tgt_id, {})

        src_file = src_node.get("source_file", "unknown")
        tgt_file = tgt_node.get("source_file", "unknown")

        if src_file == "unknown" or tgt_file == "unknown":
            continue

        # Skip self-loops (d3-sankey doesn't support circular links)
        if src_file == tgt_file:
            continue

        file_flows[(src_file, tgt_file)] += 1
        file_functions[src_file]["callees"][shorten_path(tgt_file)] += 1
        file_functions[tgt_file]["callers"][shorten_path(src_file)] += 1

    if not file_flows:
        print("No cross-file call flows found.")
        sys.exit(1)

    all_files = set()
    for (sf, tf) in file_flows:
        all_files.add(sf)
        all_files.add(tf)

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

    file_to_community = {}
    file_to_community_label = {}
    for n in nodes_raw:
        sf = n.get("source_file", "")
        if sf and sf not in file_to_community:
            c = n.get("community")
            if c is not None:
                file_to_community[sf] = int(c)
                file_to_community_label[sf] = community_labels.get(int(c), f"Community {c}")

    sankey_nodes = []
    node_index = {}
    for i, f in enumerate(sorted(all_files)):
        node_index[f] = i
        comm = file_to_community.get(f, -1)
        color = COMMUNITY_COLORS[comm % len(COMMUNITY_COLORS)] if comm >= 0 else "#999999"
        sankey_nodes.append({
            "name": shorten_path(f),
            "fullPath": f,
            "community": file_to_community_label.get(f, "unknown"),
            "color": color,
        })

    sankey_links = []
    for (sf, tf), count in file_flows.items():
        sankey_links.append({
            "source": node_index[sf],
            "target": node_index[tf],
            "value": count,
            "sourceFile": sf,
            "targetFile": tf,
        })

    tooltip_data = {}
    for f in all_files:
        short = shorten_path(f)
        callers = dict(file_functions[f]["callers"])
        callees = dict(file_functions[f]["callees"])
        tooltip_data[short] = {
            "fullPath": f,
            "community": file_to_community_label.get(f, "unknown"),
            "callers": callers,
            "callees": callees,
        }

    sankey_json = json.dumps({"nodes": sankey_nodes, "links": sankey_links})
    tooltip_json = json.dumps(tooltip_data)
    summary = f"{len(file_flows)} cross-file call flows &middot; {sum(file_flows.values())} total call edges &middot; hover for detail"

    html = HTML_TEMPLATE
    html = html.replace("__SANKEY_JSON__", sankey_json)
    html = html.replace("__TOOLTIP_JSON__", tooltip_json)
    html = html.replace("__SUMMARY__", summary)

    Path(output_path).write_text(html)
    print(f"callflow.html written — {len(sankey_nodes)} nodes, {len(sankey_links)} links")
    print(f"  Open in browser: file://{Path(output_path).resolve()}")


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <graph.json> <output.html>")
        sys.exit(1)
    build_callflow_html(sys.argv[1], sys.argv[2])
