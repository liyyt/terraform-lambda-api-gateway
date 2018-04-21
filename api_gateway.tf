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