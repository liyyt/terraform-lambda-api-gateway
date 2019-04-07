variable "name" {
  description = "Name of thing"
}

variable "region" {
  description = "Region to deploy to"
  default = "us-east-1"
}

variable "app_version" {
  description = "Version of the application"
}

variable "environment" {
  description = "Environment (staging/production)"
  default = "staging"
}

variable "s3_bucket" {
  description = "S3 bucket name"
}

variable "s3_zip_file" {
  description = "Name of the zip file (example.zip)"
}

variable "lambda_handler" {
  description = "Name of the entry js file (lambda)"
}

variable "node_version" {
  description = "Version of node to run"
  default = "8.10"
}

variable "api_gateway_description" {
  description = "Api gateway description"
  default = ""
}

// DNS
variable "domain_name" {
  description = "Domain name for api gateway"
}

variable "cdn_domain_name" {
  description = "Domain name for your cdn"
}

variable "create_dns" {
  description = "Create a DNS record"
  default = "0"
}

variable "dns_zone" {
  description = "DNS zone id"
  default = ""
}

// SSL Cert
variable "certificate_arn" {
  description = "SSL certificate ARN"
}


variable "cloudfront_origin_access_identity" {
  description = "A weird thing. Can be left empty, or add words"
  default = ""
}

variable "cloudfront_domain_aliases" {
  type = "list"
}
