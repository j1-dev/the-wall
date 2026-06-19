output "dynamodb_table_arn" {                                                      
    value = aws_dynamodb_table.dynamodb.arn
}
              
output "dynamodb_stream_arn" {                                 
    value = aws_dynamodb_table.dynamodb.stream_arn
}