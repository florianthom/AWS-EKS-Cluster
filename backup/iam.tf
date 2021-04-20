# resource "aws_iam_account_password_policy" "strict" {
#   minimum_password_length        = 8
#   require_lowercase_characters   = true
#   require_numbers                = false
#   require_uppercase_characters   = false
#   require_symbols                = false
#   allow_users_to_change_password = true
# }

# resource "aws_iam_group" "admin-group_dev_main" {
#   name = "AdministratorGroup"
# }

# resource "aws_iam_group_policy_attachment" "policy-attachment-to-admin-group_dev_main" {
#   group      = aws_iam_group.admin-group_dev_main.name
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }

# resource "aws_iam_group_membership" "add-admin-user-to-admin-group_dev_main" {
#   name = "add-admin-user-to-admin-group"
#   users = [
#     aws_iam_user.create-admin1_dev_main.name,
#     aws_iam_user.create-admin2_dev_main.name,
#     aws_iam_user.create-admin3_dev_main.name,
#   ]
#   group = aws_iam_group.admin-group_dev_main.name
# }