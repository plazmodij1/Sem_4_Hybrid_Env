variable "additional_prometheus_targets" {
  description = "Extra node_exporter or app exporter targets"
  type        = list(string)
  default     = []
}