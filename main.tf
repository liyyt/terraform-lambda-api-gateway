terraform {
  # The configuration for this backend will be filled in by Terragrunt
  backend "s3" {}
}

provider "aws" {
  region = "${var.region}"
}

data "aws_route53_zone" "main" {
  count   = "${var.create_dns}"
  zone_id = "${var.dns_zone}"
}

resource "aws_route53_record" "main" {
  count   = "${var.create_dns}"
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name = "${aws_api_gateway_domain_name.main.domain_name}"
  type = "A"

  alias {
    name                   = "${aws_api_gateway_domain_name.main.cloudfront_domain_name}"
    zone_id                = "${aws_api_gateway_domain_name.main.cloudfront_zone_id}"
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "cdn" {
  count   = "${var.create_dns}"
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name = "${var.cdn_domain_name}"
  type = "A"

  alias {
    name                   = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
    zone_id                = "${aws_cloudfront_distribution.s3_distribution.hosted_zone_id}"
    evaluate_target_health = false
  }
}

resource "aws_api_gateway_domain_name" "main" {
  domain_name = "${var.domain_name}"
  certificate_arn = "${var.certificate_arn}"
}

resource "aws_api_gateway_account" "default" {
  cloudwatch_role_arn = "${aws_iam_role.apigw.arn}"
}

resource "aws_iam_role" "apigw" {
  name = "${var.environment}-${var.name}-apigw-role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "cloudwatch" {
  name = "${var.environment}-${var.name}-apigw-cloudwatch-policy"
  role = "${aws_iam_role.apigw.id}"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:DescribeLogGroups",
                "logs:DescribeLogStreams",
                "logs:PutLogEvents",
                "logs:GetLogEvents",
                "logs:FilterLogEvents"
            ],
            "Resource": "*"
        }
    ]
}
EOF
}

resource "aws_api_gateway_rest_api" "main" {
  name        = "${var.environment}-${var.name}"
  description = "${var.api_gateway_description}"
}

resource "aws_api_gateway_deployment" "main" {
  depends_on = [
    "aws_api_gateway_integration.lambda",
    "aws_api_gateway_integration.lambda_root",
  ]

  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  stage_name  = "${var.environment}"
}

//resource "aws_api_gateway_stage" "main" {
//  deployment_id = "${aws_api_gateway_deployment.main.id}"
//  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
//  stage_name = "${var.environment}"
//}

resource "aws_api_gateway_base_path_mapping" "main" {
  api_id = "${aws_api_gateway_rest_api.main.id}"
//  stage_name = "${aws_api_gateway_stage.main.stage_name}"
  stage_name = "${aws_api_gateway_deployment.main.stage_name}"
  domain_name = "${aws_api_gateway_domain_name.main.domain_name}"
  lifecycle {
    prevent_destroy = false
  }
}

resource "aws_lambda_function" "main" {
  function_name = "${var.environment}-${var.name}"

  s3_bucket = "${var.s3_bucket}"
  s3_key    = "v${var.app_version}/${var.s3_zip_file}"

  handler = "${var.lambda_handler}.handler"
  runtime = "nodejs${var.node_version}"

  role = "${aws_iam_role.lambda.arn}"
}

resource "aws_iam_role" "lambda" {
  name = "${var.environment}-${var.name}-lambda-role"

  assume_role_policy = <<POLICY
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
POLICY
}

resource "aws_iam_role_policy" "logging" {

  name = "${var.environment}-${var.name}-lambda-logging-policy"
  role = "${aws_iam_role.lambda.id}"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "cloudwatch:*",
        "logs:*"
      ],
      "Effect": "Allow",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  parent_id   = "${aws_api_gateway_rest_api.main.root_resource_id}"
  path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.proxy.id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  resource_id = "${aws_api_gateway_method.proxy.resource_id}"
  http_method = "${aws_api_gateway_method.proxy.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.main.invoke_arn}"
}

resource "aws_api_gateway_method" "proxy_root" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_rest_api.main.root_resource_id}"
  http_method   = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda_root" {
  rest_api_id = "${aws_api_gateway_rest_api.main.id}"
  resource_id = "${aws_api_gateway_method.proxy_root.resource_id}"
  http_method = "${aws_api_gateway_method.proxy_root.http_method}"

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = "${aws_lambda_function.main.invoke_arn}"
}

resource "aws_lambda_permission" "apigw" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.main.arn}"
  principal     = "apigateway.amazonaws.com"

  # The /*/* portion grants access from any method on any resource
  # within the API Gateway "REST API".
  source_arn = "${aws_api_gateway_deployment.main.execution_arn}/*/*"
}


/** CORS stuff */
resource "aws_api_gateway_resource" "cors_resource" {
  path_part     = "Employee"
  parent_id     = "${aws_api_gateway_rest_api.main.root_resource_id}"
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
}


resource "aws_api_gateway_method" "options_method" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
  http_method   = "OPTIONS"
  authorization = "NONE"
}


resource "aws_api_gateway_method_response" "options_200" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
  http_method   = "${aws_api_gateway_method.options_method.http_method}"
  status_code   = "200"
  response_models {
    "application/json" = "Empty"
  }
  response_parameters {
    "method.response.header.Access-Control-Allow-Headers" = true,
    "method.response.header.Access-Control-Allow-Methods" = true,
    "method.response.header.Access-Control-Allow-Origin" = true
  }
  depends_on = ["aws_api_gateway_method.options_method"]
}
resource "aws_api_gateway_integration" "options_integration" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
  http_method   = "${aws_api_gateway_method.options_method.http_method}"
  type          = "MOCK"
  depends_on = ["aws_api_gateway_method.options_method"]
}
resource "aws_api_gateway_integration_response" "options_integration_response" {
  rest_api_id   = "${aws_api_gateway_rest_api.main.id}"
  resource_id   = "${aws_api_gateway_resource.cors_resource.id}"
  http_method   = "${aws_api_gateway_method.options_method.http_method}"
  status_code   = "${aws_api_gateway_method_response.options_200.status_code}"
  response_parameters = {
    "method.response.header.Access-Control-Allow-Headers" = "'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token'",
    "method.response.header.Access-Control-Allow-Methods" = "'GET,OPTIONS,POST,PUT'",
    "method.response.header.Access-Control-Allow-Origin" = "'*'"
  }
  depends_on = ["aws_api_gateway_method_response.options_200"]
}


/** CloudFront Distribution */
/** Resources

https://www.terraform.io/docs/providers/aws/r/cloudfront_distribution.html
https://github.com/fillup/terraform-aws-hugo-s3-cloudfront
https://gist.github.com/jwieringa/ef6bbbf874ac70ec81b1df3dfbf7e0a9

*/

resource "aws_s3_bucket" "assets" {
  bucket = "${var.name}-assets-${var.environment}"
  acl    = "private"

  cors_rule {
    allowed_headers = ["*"]
    allowed_methods = ["GET"]
    allowed_origins = ["*"]
    expose_headers  = ["ETag"]
    max_age_seconds = 3000
  }

  tags {
    Name = "${var.name}-assets-${var.environment}"
  }
}

locals {
  s3_origin_id = "${var.name}-s3-assets-origin-${var.environment}"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = "${aws_s3_bucket.assets.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

    s3_origin_config {
      origin_access_identity = "${var.cloudfront_origin_access_identity}"
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "${var.environment}-${var.name}-cloudfront-dist"
  default_root_object = "index.html"

  logging_config {
    include_cookies = false
    bucket          = "${var.name}-logs.s3.amazonaws.com"
    prefix          = "${var.environment}-${var.name}-logs"
  }

  aliases = ["${var.cloudfront_domain_aliases}"]

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      headers = ["Origin"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      headers = ["Origin"]
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags {
    Environment = "${var.environment}"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
    acm_certificate_arn = "${var.certificate_arn}"
    minimum_protocol_version = "TLSv1"
    ssl_support_method = "sni-only"
  }
}
