---
id: "card-wire-convergencedetector-into-sprintorchestrator-047hftj"
boardId: "default"
title: "Wire ConvergenceDetector into SprintOrchestrator halt predicate"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: "track-phase-2-semantic-convergence-entropy-collapse-de-1p60as8"
column: "backlog"
rank: "yj"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-26T04:13:37.017Z"
updatedAt: "2026-06-26T04:13:37.017Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
Extend `SprintOrchestrator#halt?` to incorporate `ConvergenceDetector#check` alongside the existing halting conditions (RQ unchanged OR budget exhausted). Halt predicate becomes: RQ stable AND no new information (convergence) OR gas budget exhausted OR all questions answered. Order matters: convergence check runs after gas check (gas exhaustion → Rolling Synthesis → fresh budget; convergence → hard halt). Acceptance: SprintOrchestrator spec covers all three halt paths.