
# resource "aws_iam_role" "role-to-access-s3_dev_main" {
#   name = "role-to-access-s3_dev_main"

#   assume_role_policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": "sts:AssumeRole",
#       "Principal": {
#         "Service": "ec2.amazonaws.com"
#       },
#       "Effect": "Allow",
#       "Sid": ""
#     }
#   ]
# }
# EOF

#   tags = {
#     Name = "role-to-access-s3"
#   }
# }

# resource "aws_iam_instance_profile" "ec2_profile" {
#   name = "ec2_profile"
#   role = aws_iam_role.role-to-access-s3_dev_main.name
# }

# resource "aws_iam_role_policy" "policy-to-access-s3_dev_main" {
#   name = "policy-to-access-s3_dev_main"
#   role = aws_iam_role.role-to-access-s3_dev_main.id

#   policy = <<EOF
# {
#   "Version": "2012-10-17",
#   "Statement": [
#     {
#       "Action": [
#         "s3:*"
#       ],
#       "Effect": "Allow",
#       "Resource": "*"
#     }
#   ]
# }
# EOF
# }

# # policy for s3, to be able to write logs from cloudtrail to the bucket
# # https://docs.aws.amazon.com/awscloudtrail/latest/userguide/create-s3-bucket-policy-for-cloudtrail.html
# # https://github.com/tmknom/terraform-aws-s3-cloudtrail/blob/master/main.tf
# data "aws_iam_policy_document" "default" {
#   statement {
#     sid    = "AWSCloudTrailAclCheck"
#     effect = "Allow"
#     principals {
#       type        = "Service"
#       identifiers = ["cloudtrail.amazonaws.com"]
#     }
#     actions = [
#       "s3:GetBucketAcl",
#     ]
#     resources = [
#       "arn:aws:s3:::${var.bucketname}",
#     ]
#   }
#   statement {
#     sid    = "AWSCloudTrailWrite"
#     effect = "Allow"
#     principals {
#       type        = "Service"
#       identifiers = ["cloudtrail.amazonaws.com"]
#     }
#     actions = [
#       "s3:PutObject",
#     ]
#     resources = [
#       "arn:aws:s3:::${var.bucketname}/*",
#     ]
#     condition {
#       test     = "StringEquals"
#       variable = "s3:x-amz-acl"
#       values = [
#         "bucket-owner-full-control",
#       ]
#     }
#   }
# }

# # create aws vpc endpoint for s3
# #   access to s3 wget https://s3-0.s3.eu-central-1.amazonaws.com/Screenshot+from+2020-06-20+20-22-29.png
# #   -> forbidden -> we need to add role to ec2
# resource "aws_vpc_endpoint" "endpoint-s3_dev_main" {
#   vpc_id       = aws_vpc.vpc_dev_main.id
#   service_name = "com.amazonaws.${var.region}.s3"
#   tags = {
#     "Name"        = "s3 bucket endpoint"
#     "environment" = "development"
#   }
# }


# # create route table association for s3-endpoint
# #  with that its possible to access s3-service from private subnet without leaving vpc
# #  verify the added route: https://eu-central-1.console.aws.amazon.com/vpc/home?region=eu-central-1#RouteTables:sort=routeTableId
#
#   for now we create an association for public subnet also
# resource "aws_vpc_endpoint_route_table_association" "vpc-endpoint-rt-public-association-s3_dev_main" {
#   route_table_id  = aws_route_table.rt_public_dev_main.id
#   vpc_endpoint_id = aws_vpc_endpoint.endpoint-s3_dev_main.id
# }


# # s3 bucket
# # access example file: https://s3-0.s3.eu-central-1.amazonaws.com/Screenshot+from+2020-06-20+20-22-29.png
# resource "aws_s3_bucket" "s3-0_dev_main" {
#   bucket        = var.bucketname
#   policy        = data.aws_iam_policy_document.default.json
#   force_destroy = true
#   acl           = "private"

#   versioning {
#     enabled = true
#   }
#   tags = {
#     "Name"        = "first s3 bucket"
#     "environment" = "development"
#   }
# }


# # cloudtrail
# resource "aws_cloudtrail" "simple-cloud-trail" {
#   name                          = "tf-trail-foobar"
#   s3_bucket_name                = aws_s3_bucket.s3-0_dev_main.id
#   s3_key_prefix                 = "test-prefix-s3"
#   include_global_service_events = true
# }