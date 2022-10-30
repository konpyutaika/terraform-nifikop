# Create NiFikop namespace if asked
resource "kubernetes_namespace" "nifikop" {
  count = var.nifikop_create_namespace ? 1 : 0
  metadata {
    annotations = {
      name = var.nifikop_namespace
    }
    name = var.nifikop_namespace
  }
}

# Deploy CRDs
resource "k8s_manifest" "nifikop_crds" {
  for_each = fileset("${path.module}/kubernetes/nifikop/crds/${var.nifikop_version}", "*")
  content  = templatefile("${path.module}/kubernetes/nifikop/crds/${var.nifikop_version}/${each.value}", {
    namespace = var.nifikop_namespace,
    certificate_name = "${var.nifikop_name}-webhook-cert",
    webhook_service_name = "${var.nifikop_name}-webhook"
  })
}

# helm release
resource "helm_release" "nifikop" {
  name         = var.nifikop_name
  repository   = "oci://ghcr.io/konpyutaika/helm-charts/" # prior 7.6 https://orange-kubernetes-charts-incubator.storage.googleapis.com/
  chart        = "nifikop"
  namespace    = var.nifikop_namespace
  version      = "0.0.2"
#  version      = var.nifikop_version
  force_update = var.force_update
  wait         = true
  timeout      = 1000

  dynamic "set" {
    for_each = var.nifikop_config
    content {
      name  = set.key
      value = set.value
    }
  }

  set {
    name  = "image.tag"
    value = var.nifikop_image_tag
  }

  set {
    name  = "namespaces"
    value = "{${join(",", var.nifikop_watch_namespaces_list)}}"
  }

  depends_on = [k8s_manifest.nifikop_crds]
}


