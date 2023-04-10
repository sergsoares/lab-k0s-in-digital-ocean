apply:
	terraform apply

destroy:
	terraform destroy

apply-cloudflare-workers:
	terraform apply -target=cloudflare_record.workers

apply-k0s-only:
	terraform apply -target=local_sensitive_file.kubeconfig

apply-argocd:
	terraform apply -target=helm_release.argocd

apply-argoapp:
	terraform apply -target=kubectl_manifest.argoapp