# Added for the layered layout: read by layer 40-observability through remote state

output "load_balancer_arn" {
  description = "ARN of the load balancer"
  value       = module.alb.load_balancer_arn
}
