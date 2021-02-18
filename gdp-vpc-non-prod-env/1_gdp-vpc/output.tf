output "private_subnets" {
  value = aws_subnet.private_subnet[*].id
}

output "public_subnet" {
  value = aws_subnet.public_subnet[*].id
}


output "db_subnets" {
  value = aws_subnet.db_subnet[*].id
}

output "nat_gateway" {
  value = aws_nat_gateway.nat_gateway[*].id
}