data "aws_iam_policy_document" "assume_ec2" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "instance" {
  name                 = "${var.name_prefix}-instance-role"
  assume_role_policy   = data.aws_iam_policy_document.assume_ec2.json
  permissions_boundary = var.permissions_boundary_arn

  tags = merge(var.tags, {
    Name = "${var.name_prefix}-instance-role"
  })
}

resource "aws_iam_instance_profile" "this" {
  name = "${var.name_prefix}-instance-profile"
  role = aws_iam_role.instance.name
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

data "aws_iam_policy_document" "runtime" {
  statement {
    actions = [
      "s3:GetObject",
      "s3:ListBucket"
    ]
    resources = var.runtime_s3_bucket_arn != null ? [
      var.runtime_s3_bucket_arn,
      "${var.runtime_s3_bucket_arn}/*"
    ] : ["*"]
  }

  statement {
    actions = [
      "ssm:GetParameter",
      "ssm:GetParameters",
      "ssm:GetParametersByPath"
    ]
    resources = length(var.runtime_ssm_parameter_arns) > 0 ? var.runtime_ssm_parameter_arns : ["*"]
  }
}

resource "aws_iam_policy" "runtime" {
  name        = "${var.name_prefix}-runtime"
  description = "Runtime access for application instances"
  policy      = data.aws_iam_policy_document.runtime.json
}

resource "aws_iam_role_policy_attachment" "runtime" {
  role       = aws_iam_role.instance.name
  policy_arn = aws_iam_policy.runtime.arn
}
