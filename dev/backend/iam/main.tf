terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      #  version = "~> 4.0"
      #  version = "~> 5"
    }
  }
}

provider "aws" {
  #  region = "us-east-1"
  region = "eu-west-1"
}

resource "aws_iam_role" "FederatedAccess" {
  name        = "FederatedAccess"
  description = "Federated Access"
  assume_role_policy = file("FederatedAccess.json")
  # assume_role_policy = jsonencode(
  #   {
  #     Version = "2012-10-17"
  #     Statement = [
  #       {
  #         Effect = "Allow"
  #         Principal = {
  #           AWS = [
  #             "arn:aws:iam::801610064192:root",
  #             "arn:aws:iam::802807423235:root",
  #             "arn:aws:iam::640693977485:root",
  #             "arn:aws:iam::743122510778:root",
  #             "arn:aws:iam::864981721433:root",
  #             "arn:aws:iam::126159560176:root",
  #             "arn:aws:iam::956474664196:root",
  #             "arn:aws:iam::568354555100:root",
  #             "arn:aws:iam::341292795870:root",
  #           ]
  #         }
  #         Action    = "sts:AssumeRole"
  #         Condition = {}
  #       },
  #     ]
  #   }
  # )
}

# resource "aws_iam_role_policy_attachment" "FederatedAccess_managed_policy" {
#   role       = "FederatedAccess"
#   policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
# }
