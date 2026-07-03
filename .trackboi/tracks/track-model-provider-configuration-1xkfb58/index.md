---
id: "track-model-provider-configuration-1xkfb58"
title: "Model Provider Configuration"
slug: "model-provider-configuration"
createdAt: "2026-06-25T04:35:17.762Z"
updatedAt: "2026-07-03T05:42:02.797Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Per-task model selection (which model runs Pass 2 annotation, narrative generation, Achilles vs. Tortoise in sprint roles, etc.) instead of one global `DSPY_PROVIDER`. Start CLI/config-file based (likely `tty-config`), with an eye toward a future UI settings screen. Model lists must be filtered to providers/models that actually support the capabilities a given task needs (structured output, tool use, reasoning) — not a raw unfiltered provider catalog.