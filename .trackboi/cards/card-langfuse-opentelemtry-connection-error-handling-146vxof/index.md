---
id: "card-langfuse-opentelemtry-connection-error-handling-146vxof"
boardId: "default"
title: "langfuse/opentelemtry connection error handling"
parentId: null
scope: {"kind":"project","ref":"global"}
trackId: null
column: "done"
rank: "j"
labels: []
assignee: null
fieldValues: {}
createdAt: "2026-06-25T00:31:48.704Z"
updatedAt: "2026-06-25T05:51:18.558Z"
createdBy: "person_01KVMJ5P8X1YH265RRBTNDVX4T"
updatedBy: "agent_01KT5NHKJ8RYCC6HW5SF8RZ1JR"
---
- [ ] when unable to connect to Langfuse/Opentelemtry, there should be an error display that a) explains why and b) prompts the user to continue without tracing to cancel the job

```
"""  65/293 (Robert)... E, [2026-06-24T20:27:19.277163 #608091] ERROR -- : OpenTelemetry error: unexpected error decoding rpc.Status in OTLP::Exporter#log_status - Error occurred during parsing -
  /home/b08x/.local/share/gem/ruby/3.4.0/gems/opentelemetry-exporter-otlp-0.34.0/lib/opentelemetry/exporter/otlp/exporter.rb:243:in 'Google::Protobuf::AbstractMessage.decode'
  E, [2026-06-24T20:27:19.514564 #608091] ERROR -- : OpenTelemetry error: unexpected error decoding rpc.Status in OTLP::Exporter#log_status - Error occurred during parsing -
  /home/b08x/.local/share/gem/ruby/3.4.0/gems/opentelemetry-exporter-otlp-0.34.0/lib/opentelemetry/exporter/otlp/exporter.rb:243:in 'Google::Protobuf::AbstractMessage.decode'
  E, [2026-06-24T20:27:19.951124 #608091] ERROR -- : OpenTelemetry error: unexpected error decoding rpc.Status in OTLP::Exporter#log_status - Error occurred during parsing -
  /home/b08x/.local/share/gem/ruby/3.4.0/gems/opentelemetry-exporter-otlp-0.34.0/lib/opentelemetry/exporter/otlp/exporter.rb:243:in 'Google::Protobuf::AbstractMessage.decode'
  E, [2026-06-24T20:27:20.797561 #608091] ERROR -- : OpenTelemetry error: unexpected error decoding rpc.Status in OTLP::Exporter#log_status - Error occurred during parsing -
  /home/b08x/.local/share/gem/ruby/3.4.0/gems/opentelemetry-exporter-otlp-0.34.0/lib/opentelemetry/exporter/otlp/exporter.rb:243:in 'Google::Protobuf::AbstractMessage.decode'
  18.98s [OK]
    66/293 (Steve)... ^C
  [INFO] Stopping after the current turn finishes... (Ctrl+C again to force quit)"""
```