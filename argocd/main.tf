# see https://registry.terraform.io/providers/oboukili/argocd/latest/docs/resources/project
resource "argocd_project" "example" {
  metadata {
    name      = "example"
    namespace = "argocd"
  }
  spec {
    source_repos = ["*"]
    destination {
      server    = "*"
      namespace = "*"
    }
    cluster_resource_whitelist {
      group = "*"
      kind  = "*"
    }
  }
}

# see https://argo-cd.readthedocs.io/en/stable/user-guide/helm/
# see https://artifacthub.io/packages/helm/bitnami/nginx
# see https://github.com/bitnami/charts/tree/main/bitnami/nginx
# see https://github.com/argoproj/argocd-example-apps
# see https://registry.terraform.io/providers/oboukili/argocd/latest/docs/resources/application
resource "argocd_application" "nginx" {
  metadata {
    name      = "nginx"
    namespace = "argocd"
  }

  wait = true

  spec {
    project = argocd_project.example.id

    destination {
      name      = "in-cluster"
      namespace = "default"
    }

    source {
      repo_url        = "registry-1.docker.io/bitnamicharts"
      chart           = "nginx"
      target_revision = "18.1.2"
      helm {
        values = yamlencode({
          serverBlock = <<-EOS
          server {
            listen 0.0.0.0:8080;
            location / {
              return 200 "nginx: Hello, World!\n";
            }
          }
          EOS
        })
      }
    }

    sync_policy {
      automated {
        prune       = true
        self_heal   = true
        allow_empty = true
      }
      retry {
        limit = "5"
        backoff {
          duration     = "30s"
          max_duration = "2m"
          factor       = "2"
        }
      }
    }
  }
}
