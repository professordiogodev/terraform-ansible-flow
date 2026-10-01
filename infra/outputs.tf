# output
output "public_ip" {
  value       = aws_instance.app.public_ip
  description = "The public IP address of your AL2023 web server."
}
