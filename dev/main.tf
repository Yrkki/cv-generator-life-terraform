provider "aws" {
  region = "eu-west-1"
}

resource "aws_cloudformation_stack" "network" {
  name = "CvGenerator"
  capabilities = ["CAPABILITY_IAM"]
  
  parameters {
    ManagerSize = "1"
    ClusterSize = "1"
    KeyName = "docker"
  }

  template_body = "${file("cv-generator.tmpl.json")}"
}
