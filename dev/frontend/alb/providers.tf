# -----------------------------------------------------------------------------
# AWS PROVIDER CONFIGURATION
# -----------------------------------------------------------------------------
# This block configures the default AWS provider, specifying the region and 
# using an assumed role for authentication.
# -----------------------------------------------------------------------------
provider "aws" {
  # Use the region defined in the variables-main.tf
  region = var.region

  # Configure assumed role access using the ARN defined in locals.config.role_arn
  assume_role {
    role_arn = local.config.role_arn
  }
}

# Note: If you need to interact with multiple regions (like us-east-1 for ACM) 
# you should define additional provider blocks with aliases here.
# For example:
/*
provider "aws" {
  alias  = "us_east_1"
  region = var.cert_source_region # The variable for us-east-1

  assume_role {
    role_arn = local.config.role_arn
  }
}
*/
