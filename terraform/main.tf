terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
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
    dynamodb = "http://localhost:4566"
    lambda   = "http://localhost:4566"
    iam      = "http://localhost:4566"
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

data "archive_file" "lamda_zip" {
  type        = "zip"
  source_dir  = "../lambdas/websocket-handler"
  output_path = "../lambdas/websocket-handler.zip"
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
resource "aws_iam_role" "websocket_handler_role" {
  name               = "test_role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
}

resource "aws_iam_role_policy" "websocket_handler_policy" {
  name   = "websocket-handler-dynamodb-policy"
  role   = aws_iam_role.websocket_handler_role.id
  policy = data.aws_iam_policy_document.websocket_policy.json
}

resource "aws_lambda_function" "websocket_handler" {
  runtime          = "nodejs22.x"
  handler          = "dist/index.handler"
  function_name    = "websocket-handler"
  role             = aws_iam_role.websocket_handler_role.arn
  filename         = data.archive_file.lamda_zip.output_path
  source_code_hash = data.archive_file.lamda_zip.output_base64sha256
  environment {
    variables = {
      TABLE_NAME = "the-wall"
    }
  }
}
