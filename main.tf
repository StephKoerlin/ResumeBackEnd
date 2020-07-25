provider "aws" {
  region = var.aws_region
}

#The configuration for the `remote` backend
terraform {
  backend "remote" {
    # The name of your Terraform Cloud organization
    organization = "StephKoerlin"

    # The name of the Terraform Cloud workspace to store Terraform state files in
    workspaces {
      name = "ResumeProd"
    }
  }
}


#-----S3-----

#create the static website bucket in S3

resource "aws_s3_bucket" "resume_code" {
  bucket = var.domain_name
  acl    = "private"

  website {
    index_document = "index.html"
    error_document = "404.html"
  }
}

#-----CloudFront-----

#origin access identity

resource "aws_cloudfront_origin_access_identity" "resumeOA" {
  comment = "origin access for my resume distribution"
}

#cloudfront distribution

resource "aws_cloudfront_distribution" "s3_distribution" {
  depends_on = [aws_cloudfront_origin_access_identity.resumeOA]

  origin {
    domain_name = aws_s3_bucket.resume_code.bucket_regional_domain_name
    origin_id   = aws_cloudfront_origin_access_identity.resumeOA.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.resumeOA.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  aliases = [
    var.domain_name,
  "www.${var.domain_name}"]

  default_cache_behavior {
    allowed_methods = [
      "DELETE",
      "GET",
      "HEAD",
      "OPTIONS",
      "PATCH",
      "POST",
    "PUT"]
    cached_methods = [
      "GET",
    "HEAD"]
    target_origin_id = aws_cloudfront_origin_access_identity.resumeOA.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations = ["*"]
    }
  }

  viewer_certificate {
    acm_certificate_arn      = aws_acm_certificate_validation.cert.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2019"
  }
}

#-----ACM Certificate-----

#create new acm

resource "aws_acm_certificate" "cert" {
  domain_name               = var.domain_name
  subject_alternative_names = ["www.${var.domain_name}"]
  validation_method         = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "cert_validation" {
  name    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.0.resource_record_type
  zone_id = data.aws_route53_zone.primary.zone_id
  records = [aws_acm_certificate.cert.domain_validation_options.0.resource_record_value]
  ttl     = 60
}

resource "aws_route53_record" "cert_validation_alt1" {
  name    = aws_acm_certificate.cert.domain_validation_options.1.resource_record_name
  type    = aws_acm_certificate.cert.domain_validation_options.1.resource_record_type
  zone_id = data.aws_route53_zone.primary.zone_id
  records = [aws_acm_certificate.cert.domain_validation_options.1.resource_record_value]
  ttl     = 60
}

resource "aws_acm_certificate_validation" "cert" {
  certificate_arn = aws_acm_certificate.cert.arn
  validation_record_fqdns = [
    aws_route53_record.cert_validation.fqdn,
    aws_route53_record.cert_validation_alt1.fqdn
  ]
}

#-----Route53-----

#import zone already made for blog

data "aws_route53_zone" "primary" {
  name = var.domain_name
}

#www

resource "aws_route53_record" "www" {
  name    = "www.${var.domain_name}"
  type    = "A"
  zone_id = data.aws_route53_zone.primary.zone_id

  alias {
    evaluate_target_health = false
    name                   = aws_cloudfront_distribution.s3_distribution.domain_name
    zone_id                = aws_cloudfront_distribution.s3_distribution.hosted_zone_id
  }
}

#-----DynamoDB-----

#table

resource "aws_dynamodb_table" "VisitorTable" {
  hash_key     = "Site"
  name         = "VisitorTable"
  billing_mode = "PAY_PER_REQUEST"
  attribute {
    name = "Site"
    type = "S"
  }
}

#add first item but only the first time run

resource "aws_dynamodb_table_item" "VisitorTableItem" {
  table_name = aws_dynamodb_table.VisitorTable.name
  hash_key   = aws_dynamodb_table.VisitorTable.hash_key
  lifecycle { ignore_changes = [item] }

  item = <<ITEM
{
  "Site": {"S": "Resume"},
  "Visitors": {"N": "0"}
}
ITEM
}

#-----Lambda-----

#policy for lambda to use to get to dynamoDB

resource "aws_iam_policy" "dynamoDB_policy" {
  name        = "DynamoPolicy"
  description = "policy to allow dynamoDB access"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": "dynamodb:*",
            "Resource": "arn:aws:dynamodb:us-east-1:375586692792:table/VisitorTable"
        }
    ]
}
EOF
}

#role for lambda to use

resource "aws_iam_role" "iam_for_lambda" {
  name = "LambdaRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

#attach role to dynamoDB policy

resource "aws_iam_role_policy_attachment" "Attach" {
  role       = aws_iam_role.iam_for_lambda.name
  policy_arn = aws_iam_policy.dynamoDB_policy.arn
}

#lambda function

resource "aws_lambda_function" "Visitor_Function" {
  filename         = var.visitor_function
  function_name    = "VisitorFunction"
  role             = aws_iam_role.iam_for_lambda.arn
  handler          = "lambda_function.lambda_handler"
  source_code_hash = filebase64sha256(var.visitor_function)
  runtime          = "python3.8"
}

#-----API Gateway-----

#api

resource "aws_api_gateway_rest_api" "Visitor_API" {
  name        = "VisitorAPI"
  description = "API for counting visits to my site"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

#create resource for api that will use cors

resource "aws_api_gateway_resource" "cors_resource" {
  path_part   = "Visitors"
  parent_id   = aws_api_gateway_rest_api.Visitor_API.root_resource_id
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
}

#create options method is required for cors

resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = aws_api_gateway_rest_api.Visitor_API.id
  resource_id   = aws_api_gateway_resource.cors_resource.id
  http_method   = "OPTIONS"
  authorization = "NONE"
}

#sets up cors

resource "aws_api_gateway_method_response" "options_response_200" {
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
  resource_id = aws_api_gateway_resource.cors_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin"  = true
  }
  depends_on = [aws_api_gateway_method.options_method]
}

#creates integration as a mock attachment for options method

resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
  resource_id = aws_api_gateway_resource.cors_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  type        = "MOCK"
  depends_on  = [aws_api_gateway_method.options_method]
}

#creates response for the integration for options method

resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
  resource_id = aws_api_gateway_resource.cors_resource.id
  http_method = aws_api_gateway_method.options_method.http_method
  status_code = aws_api_gateway_method_response.options_response_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin"  = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.options_response_200]
}

#create method for api call

resource "aws_api_gateway_method" "get_method" {
  rest_api_id   = aws_api_gateway_rest_api.Visitor_API.id
  resource_id   = aws_api_gateway_resource.cors_resource.id
  http_method   = "GET"
  authorization = "NONE"
}

#create response for get method

resource "aws_api_gateway_method_response" "get_response_200" {
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
  resource_id = aws_api_gateway_resource.cors_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = true
  }
  depends_on = [aws_api_gateway_method.get_method]
}

#creates lambda integration for get method, lambda only accepts post

resource "aws_api_gateway_integration" "get_integration" {
  rest_api_id             = aws_api_gateway_rest_api.Visitor_API.id
  resource_id             = aws_api_gateway_resource.cors_resource.id
  http_method             = aws_api_gateway_method.get_method.http_method
  integration_http_method = "POST"
  type                    = "AWS"
  uri                     = aws_lambda_function.Visitor_Function.invoke_arn
  depends_on              = [aws_api_gateway_method.get_method, aws_lambda_function.Visitor_Function]
}

#creates response to get integration

resource "aws_api_gateway_integration_response" "get_integration_response" {
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
  resource_id = aws_api_gateway_resource.cors_resource.id
  http_method = aws_api_gateway_method.get_method.http_method
  status_code = aws_api_gateway_method_response.get_response_200.status_code
  response_parameters = {
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = [aws_api_gateway_method_response.get_response_200]
}

#deploy api to Prod stage

resource "aws_api_gateway_deployment" "deployment" {
  rest_api_id = aws_api_gateway_rest_api.Visitor_API.id
  stage_name  = "Prod"

  triggers = {
    redeployment = sha1(join(",", list(
      jsonencode(aws_api_gateway_integration.get_integration),
    )))
  }

  depends_on = [aws_api_gateway_integration.get_integration]
}

#allow api to invoke lambda

resource "aws_lambda_permission" "apigw_lambda" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.Visitor_Function.arn
  principal     = "apigateway.amazonaws.com"
  source_arn    = "arn:aws:execute-api:${var.aws_region}:${var.accountID}:${aws_api_gateway_rest_api.Visitor_API.id}/*/${aws_api_gateway_method.get_method.http_method}${aws_api_gateway_resource.cors_resource.path}"
}
