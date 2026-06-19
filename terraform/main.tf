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
    }
}

resource "aws_dynamodb_table" "dynamodb" {
    name = "the-wall"
    billing_mode = "PAY_PER_REQUEST"
    hash_key = "PK"
    range_key = "SK"

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
        name = "type-index"
        hash_key = "type"
        projection_type = "ALL"
    }

    stream_enabled   = true
    stream_view_type = "NEW_IMAGE"
}