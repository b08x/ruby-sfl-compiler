---
id: "track-phase-2-runtime-decoupling-distributed-scaling-0q7iouw"
title: "Phase 2 — Runtime Decoupling (Distributed Scaling)"
slug: "phase-2-runtime-decoupling-distributed-scaling"
createdAt: "2026-06-26T04:11:56.998Z"
updatedAt: "2026-07-03T10:20:14.112Z"
createdBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
updatedBy: "person_01KWKQTR2EN5M87XNQFEXHRQ1M"
---
Replace the in-process PyCall bridge with a standalone syntactic service so that Pass 1 and Pass 2 can scale independently across machines. This is a scalability concern, not a thread-safety fix — the Gush/Sidekiq process-isolation model already resolves the PyCall threading issue. Runtime decoupling targets enterprise-volume scenarios where 50 Pass 1 workers and 20 Pass 2 workers must run on separate machines. See ROADMAP.md §Supporting Architecture Changes.