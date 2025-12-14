[working-directory: 'provisioning']
provision:
    tofu apply -var-file=cluster.tfvars 

[working-directory: 'provisioning']
deprovision:
    tofu destroy -var-file=cluster.tfvars 

[working-directory: 'configuring']
configure:
    uv run ansible-galaxy role install -r role-requirements.yml
    uv run ansible-playbook -i inventory playbooks/minikube.yml
    uv run --env-file ../.env ansible-playbook -i inventory playbooks/monitoring.yml
    uv run ansible-playbook -i inventory playbooks/ci.yml

[working-directory: 'configuring']
deploy playbook:
    uv run --env-file ../../{{ playbook}}/.env ansible-playbook -i inventory playbooks/{{ playbook }}.yml
