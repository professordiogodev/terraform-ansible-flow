# output
output "public_ip" {
  value = {
    for k, instance in aws_instance.app :
    k => instance.public_ip
  }
  description = "The public IP address of your AL2023 web server."
}

output "alb_dns" {
  value = aws_lb.app.dns_name
}