terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  access_key = "test"
  secret_key = "test"
  region     = "us-east-1"

  s3_use_path_style           = true
  skip_credentials_validation = true
  skip_metadata_api_check     = true
  skip_requesting_account_id  = true

  endpoints {
    dynamodb     = "http://localhost:4566"
    lambda       = "http://localhost:4566"
    iam          = "http://localhost:4566"
    apigatewayv2 = "http://localhost:4566"
  }
}

resource "aws_dynamodb_table" "dynamodb" {
  name         = "the-wall"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "type"
    type = "S"
  }

  global_secondary_index {
    name            = "type-index"
    hash_key        = "type"
    projection_type = "ALL"
  }

  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
}


resource "null_resource" "build_websocket_handler" {
  triggers = {
    source_hash = filemd5("../lambdas/websocket-handler/index.ts")
  }

  provisioner "local-exec" {
    command     = "npm run build"
    working_dir = "../lambdas/websocket-handler"
  }
}

resource "null_resource" "build_fanout" {
  triggers = {
    source_hash = filemd5("../lambdas/fanout/index.ts")
  }

  provisioner "local-exec" {
    command     = "npm run build"
    working_dir = "../lambdas/fanout"
  }
}

data "archive_file" "lambda_zip_websocket" {
  depends_on = [ null_resource.build_websocket_handler ]
  type        = "zip"
  source_dir  = "../lambdas/websocket-handler/dist"
  output_path = "../lambdas/websocket-handler.zip"
}

data "archive_file" "lambda_zip_fanout" {
  depends_on = [ null_resource.build_fanout ]
  type        = "zip"
  source_dir  = "../lambdas/fanout/dist"
  output_path = "../lambdas/fanout.zip"
}

data "aws_iam_policy_document" "assume_role" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

data "aws_iam_policy_document" "websocket_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:PutItem", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.dynamodb.arn]
  }
}

data "aws_iam_policy_document" "fanout_policy" {
  statement {
    effect    = "Allow"
    actions   = ["dynamodb:Query", "dynamodb:DeleteItem"]
    resources = [aws_dynamodb_table.dynamodb.arn]
  }
  statement {
    effect    = "Allow"
    actions   = ["execute-api:ManageConnections"]
    resources = ["${aws_apigatewayv2_api.gateway.execution_arn}/*"]
  }
}

resource "aws_iam_role" "websocket_handler_role" {
  name               = "test_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role" "fanout_role" {
  name               = "test_role_2"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "websocket_handler_policy" {
  name   = "websocket-handler-dynamodb-policy"
  role   = aws_iam_role.websocket_handler_role.id
  policy = data.aws_iam_policy_document.websocket_policy.json
}

resource "aws_iam_role_policy" "fanout_handler_policy" {
  name   = "fanout-policy"
  role   = aws_iam_role.fanout_role.id
  policy = data.aws_iam_policy_document.fanout_policy.json
}

resource "aws_lambda_function" "websocket_handler" {
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  function_name    = "websocket-handler"
  role             = aws_iam_role.websocket_handler_role.arn
  filename         = data.archive_file.lambda_zip_websocket.output_path
  source_code_hash = data.archive_file.lambda_zip_websocket.output_base64sha256
  environment {
    variables = {
      TABLE_NAME        = "the-wall"
      DYNAMODB_ENDPOINT = "http://localhost:4566"
    }
  }
}

resource "aws_lambda_function" "fanout" {
  runtime          = "nodejs22.x"
  handler          = "index.handler"
  function_name    = "fanout"
  role             = aws_iam_role.fanout_role.arn
  filename         = data.archive_file.lambda_zip_fanout.output_path
  source_code_hash = data.archive_file.lambda_zip_fanout.output_base64sha256
  environment {
    variables = {
      WEBSOCKET         = "http://localhost:4566"
      TABLE_NAME        = "the-wall"
      DYNAMODB_ENDPOINT = "http://localhost:4566"
    }
  }
}

resource "aws_lambda_event_source_mapping" "fanout_mapping" {
  event_source_arn = aws_dynamodb_table.dynamodb.stream_arn
  function_name = aws_lambda_function.fanout.arn
  starting_position = "LATEST"
}

resource "aws_apigatewayv2_api" "gateway" {
  name                       = "gateway"
  protocol_type              = "WEBSOCKET"
  route_selection_expression = "$request.body.action"
}

resource "aws_apigatewayv2_integration" "integration" {
  api_id           = aws_apigatewayv2_api.gateway.id
  integration_type = "AWS_PROXY"
  integration_uri  = aws_lambda_function.websocket_handler.invoke_arn
}

resource "aws_apigatewayv2_route" "connect_route" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "$connect"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_route" "disconnect_route" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "$disconnect"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}
resource "aws_apigatewayv2_route" "default_route" {
  api_id    = aws_apigatewayv2_api.gateway.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.integration.id}"
}

resource "aws_apigatewayv2_stage" "stage" {
  api_id      = aws_apigatewayv2_api.gateway.id
  name        = "local"
  auto_deploy = true
}

resource "aws_lambda_permission" "allow_lambda" {
  statement_id  = "AllowGatewayInvokeLambda"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.websocket_handler.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.gateway.execution_arn}/*"
}
