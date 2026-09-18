resource "aws_cloudwatch_log_group" "this" {
  name              = "/personal-lab/${var.name}/vpc-flow"
  retention_in_days = var.retention_days
  tags              = { Name = "${var.name}-flow-logs" }
}
resource "aws_iam_role" "flow" {
  name = "${var.name}-flow-logs"
  assume_role_policy = jsonencode({ Version = "2012-10-17", Statement = [{
    Effect    = "Allow", Principal = { Service = "vpc-flow-logs.amazonaws.com" }, Action = "sts:AssumeRole",
    Condition = { StringEquals = { "aws:SourceAccount" = var.account_id }, ArnLike = { "aws:SourceArn" = "arn:aws:ec2:${var.region}:${var.account_id}:vpc-flow-log/*" } }
  }] })
}
resource "aws_iam_role_policy" "flow" {
  name = "write-only-lab-flow-group"
  role = aws_iam_role.flow.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents", "logs:DescribeLogStreams"], Resource = "${aws_cloudwatch_log_group.this.arn}:*" },
    { Effect = "Allow", Action = ["logs:DescribeLogGroups"], Resource = "*" }
  ] })
}
resource "aws_flow_log" "this" {
  for_each                 = var.vpc_ids
  vpc_id                   = each.value
  iam_role_arn             = aws_iam_role.flow.arn
  log_destination          = aws_cloudwatch_log_group.this.arn
  log_destination_type     = "cloud-watch-logs"
  traffic_type             = "ALL"
  max_aggregation_interval = 60
  # Standard 14-field version 2 format; docs/queries.md parses it explicitly.
  tags       = { Name = "${var.name}-${each.key}" }
  depends_on = [aws_iam_role_policy.flow]
}
output "log_group_name" { value = aws_cloudwatch_log_group.this.name }
output "flow_log_ids" { value = [for f in aws_flow_log.this : f.id] }
