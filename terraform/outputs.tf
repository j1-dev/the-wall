output "dynamodb_table_arn" {
  value = aws_dynamodb_table.dynamodb.arn
}

output "dynamodb_stream_arn" {
  value = aws_dynamodb_table.dynamodb.stream_arn
}

output "websocket_handler_arn" {
  value = aws_lambda_function.websocket_handler.arn
} 
