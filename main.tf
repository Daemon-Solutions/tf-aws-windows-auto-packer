#s3

resource "aws_s3_bucket" "lambda_auto_packer" {
  bucket        = "${var.customer}-${var.envtype}-auto-packer"
  force_destroy = true

  tags {
    Name        = "${var.customer}"
    Environment = "${var.envname}"
    Envtype     = "${var.envtype}"
  }
}

resource "aws_s3_bucket_notification" "bucket_notification" {
  bucket = "${aws_s3_bucket.lambda_auto_packer.id}"

  lambda_function {
    lambda_function_arn = "${aws_lambda_function.lambda_auto_packer.arn}"
    events              = ["s3:ObjectCreated:*"]
    filter_suffix       = ".json"
  }
}

#lambda

data "archive_file" "create_auto_packer_package" {
  type        = "zip"
  source_dir  = "${path.module}/include/auto-packer"
  output_path = ".terraform/auto-packer.zip"
}

resource "aws_iam_role" "lambda_auto_packer" {
  name = "${var.customer}-lambda-auto-packer"

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

resource "aws_lambda_function" "lambda_auto_packer" {
  filename         = ".terraform/auto-packer.zip"
  source_code_hash = "${data.archive_file.create_auto_packer_package.output_base64sha256}"
  function_name    = "auto-packer"
  role             = "${aws_iam_role.lambda_auto_packer.arn}"
  handler          = "lambda_function.lambda_handler"
  runtime          = "python2.7"
  timeout          = "300"

  environment {
    variables = {
      env_image_id             = "${var.env_image_id}"
      env_instance_type        = "${var.env_instance_type}"
      env_keyname              = "${var.env_keyname}"
      env_subnet_id            = "${var.env_subnet_id}"
      env_security_group       = "${aws_security_group.auto-packer.id}"
      env_instance_profile_arn = "${module.auto_packer_iam_instance_profile.profile_arn}"
      env_s3_bucket            = "${aws_s3_bucket.lambda_auto_packer.id}"
    }
  }
}

resource "aws_lambda_permission" "allow_bucket" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = "${aws_lambda_function.lambda_auto_packer.arn}"
  principal     = "s3.amazonaws.com"
  source_arn    = "${aws_s3_bucket.lambda_auto_packer.arn}"
}

#iam

resource "aws_iam_policy" "auto-packer" {
  name        = "${var.customer}-auto-packer-runner"
  path        = "/"
  description = "auto packer policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:*",
        "s3:*",
        "ec2:*",
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach-auto-packer" {
  name       = "${var.customer}-allow-access-to-s3-ec2"
  roles      = ["${aws_iam_role.lambda_auto_packer.name}"]
  policy_arn = "${aws_iam_policy.auto-packer.arn}"
}

resource "aws_iam_policy" "iam-passrole" {
  name        = "${var.customer}-iam-passrole"
  path        = "/"
  description = "auto packer policy"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_policy_attachment" "attach-iam-passrole" {
  name       = "${var.customer}-allow-ec2-assign-instance-profile"
  roles      = ["${module.auto_packer_iam_instance_profile.role_id}"]
  policy_arn = "${aws_iam_policy.iam-passrole.arn}"
}

module "auto_packer_iam_instance_profile" {
  source = "../../modules/tf-aws-iam-instance-profile"

  name             = "${var.customer}-auto-packer"
  packer_access    = "1"
  s3_readonly      = "1"
  s3_write_buckets = "${aws_s3_bucket.lambda_auto_packer.id}"
}

resource "aws_security_group" "auto-packer" {
  name = "${var.customer}-auto-packer"

  vpc_id      = "${var.vpc_id}"
  description = "auto packer cluster security group"

  tags {
    customer = "${var.customer}"
    envname  = "${var.envname}"
    envtype  = "${var.envtype}"
  }
}

#security groups

resource "aws_security_group_rule" "autopacker_winrm_out" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = "5985"
  to_port           = "5985"
  security_group_id = "${aws_security_group.auto-packer.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "autopacker_80_out" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = "80"
  to_port           = "80"
  security_group_id = "${aws_security_group.auto-packer.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "autopacker_443_out" {
  type              = "egress"
  protocol          = "tcp"
  from_port         = "443"
  to_port           = "443"
  security_group_id = "${aws_security_group.auto-packer.id}"
  cidr_blocks       = ["0.0.0.0/0"]
}
