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
  default = "6.10"
}

variable "api_gateway_description" {
  description = "Api gateway description"
  default = ""
}

// DNS
variable "create_dns" {
  description = "Create a DNS record"
  default = "0"
}

variable "dns_zone" {
  description = "DNS zone id"
  default = ""
}

variable "dns_record_name" {
  description = "Record name"
  default = ""
}

variable "dns_records" {
  description = "Records to add [\"www.site.com\"]"
  type = "list"
}

variable "dns_record_type" {
  description = "Record type (A/CNAME)"
  default = "A"
}

variable "dns_ttl" {
  description = "DNS TTL"
  default = "300"
}