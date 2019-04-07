output "base_url" {
  value = "${aws_api_gateway_deployment.main.invoke_url}"
}

output "logs_url" {
  value = "https://console.aws.amazon.com/cloudwatch/home?region=${var.region}#logStream:group=/aws/lambda/${aws_api_gateway_rest_api.main.name}"
}

output "cloudfront_url" {
  value = "${aws_cloudfront_distribution.s3_distribution.domain_name}"
}

output "cloudfront_zoneid" {
  value = "${aws_cloudfront_distribution.s3_distribution.hosted_zone_id}"
}
