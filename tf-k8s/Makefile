apply:
	terraform apply

target:
	SELECTED=`cat main.tf | grep resource | tr -d '"' | awk '{ print $$2 "."  $$3 }' | fzf` ; \
	terraform apply -target=$$SELECTED

destroy:
	SELECTED=`cat main.tf | grep resource | tr -d '"' | awk '{ print $$2 "."  $$3 }' | fzf` ; \
	terraform destroy -target=$$SELECTED

destroy-all:
	terraform destroy

apply-cloudflare-workers:
	terraform apply -target=cloudflare_record.workers

apply-k0s-only:
	terraform apply -target=local_sensitive_file.kubeconfig

apply-argocd:
	terraform apply -target=helm_release.argocd

apply-argoapp:
	terraform apply -target=kubectl_manifest.argoapp
