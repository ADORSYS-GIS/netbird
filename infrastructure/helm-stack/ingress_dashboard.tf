resource "kubectl_manifest" "netbird_dashboard_master_ingress" {
  depends_on = [helm_release.netbird]
  
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: netbird-dashboard-master
      namespace: ${var.namespace}
      annotations:
        nginx.org/mergeable-ingress-type: "master"
        cert-manager.io/cluster-issuer: "${var.cert_issuer_name}"
        nginx.org/redirect-to-https: "true"
        kubernetes.io/ingress.class: "${var.ingress_class_name}"
    spec:
      ingressClassName: ${var.ingress_class_name}
      tls:
        - secretName: netbird-tls
          hosts:
            - ${var.netbird_domain}
      rules:
        - host: ${var.netbird_domain}
  YAML
}

resource "kubectl_manifest" "netbird_dashboard_minion_ingress" {
  depends_on = [
    helm_release.netbird,
    kubectl_manifest.netbird_dashboard_master_ingress
  ]
  
  yaml_body = <<-YAML
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: netbird-dashboard-minion
      namespace: ${var.namespace}
      annotations:
        nginx.org/mergeable-ingress-type: "minion"
        kubernetes.io/ingress.class: "${var.ingress_class_name}"
    spec:
      ingressClassName: ${var.ingress_class_name}
      rules:
        - host: ${var.netbird_domain}
          http:
            paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: netbird-dashboard
                    port:
                      number: 80
  YAML
}
