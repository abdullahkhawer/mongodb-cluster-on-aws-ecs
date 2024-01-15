resource "aws_ssm_parameter" "mongodb_endpoints" {
  name        = "/docker/${var.env_name}/MONGODB_ENDPOINTS"
  description = "Parameter having MongoDB endpoints"
  type        = "SecureString"
  overwrite   = true
  value       = join(",", formatlist("${var.env_name}-${var.service_name}%s.${var.hosted_zone_name}", range(1, var.number_of_instances + 1)))

  tags = {
    Name        = "/docker/${var.env_name}/MONGODB_ENDPOINTS"
    Environment = var.env_name
  }
}