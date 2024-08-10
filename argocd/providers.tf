# see https://github.com/hashicorp/terraform
terraform {
  required_version = "1.9.4"
  required_providers {
    # see https://registry.terraform.io/providers/oboukili/argocd
    # see https://github.com/argoproj-labs/terraform-provider-argocd
    argocd = {
      source  = "oboukili/argocd"
      version = "6.1.1"
    }
  }
}
