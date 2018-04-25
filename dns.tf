data "aws_route53_zone" "main" {
  count = "${var.create_dns}"
  zone_id = "${var.dns_zone}"
}

resource "aws_route53_record" "main" {
  count = "${var.create_dns}"
  zone_id = "${data.aws_route53_zone.main.zone_id}"
  name = "${var.dns_record_name}"
  type = "${var.dns_record_type}"
  ttl = "${var.dns_ttl}"
  records = ["${var.dns_records}"]
}

