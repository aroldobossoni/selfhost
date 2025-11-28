# Selfhost Infrastructure Makefile
# Provides clean phase-based deployment

.PHONY: help deps init lint phase1 phase2 bootstrap apply destroy clean

PYTHON := python3
VENV := .venv
PIP := $(VENV)/bin/pip
PYTHON_VENV := $(VENV)/bin/python

# Default target
help:
	@echo "Selfhost Infrastructure - Available targets:"
	@echo ""
	@echo "  make deps       - Check and install system dependencies"
	@echo "  make init       - Initialize Terraform and Python environment"
	@echo "  make lint       - Run all linters (tflint, pylint)"
	@echo "  make phase1     - Deploy LXC container with Docker"
	@echo "  make phase2     - Deploy Infisical containers"
	@echo "  make bootstrap  - Bootstrap Infisical and create credentials"
	@echo "  make apply      - Full apply (all phases)"
	@echo "  make destroy    - Destroy all infrastructure"
	@echo "  make clean      - Clean temporary files"
	@echo ""

# Check system dependencies
deps:
	@$(PYTHON) scripts/deploy.py deps

# Setup Python virtual environment
$(VENV)/bin/activate: requirements.txt
	@$(PYTHON) -m venv $(VENV) || (echo "Run: sudo apt install python3-venv" && exit 1)
	@$(PIP) install --upgrade pip -q
	@$(PIP) install -r requirements.txt -q
	@touch $(VENV)/bin/activate

# Initialize everything
init: $(VENV)/bin/activate
	@echo "==> Initializing Terraform..."
	@terraform init -upgrade
	@echo "==> Environment ready"

# Run linters
lint: $(VENV)/bin/activate
	@echo "==> Running terraform validate..."
	@terraform validate
	@echo "==> Running tflint..."
	@tflint --recursive --format compact || true
	@echo "==> Running pylint..."
	@$(PYTHON_VENV) -m pylint scripts/*.py --disable=C0114,C0115,C0116,W0718 || true
	@echo "==> Linting complete"

# Phase 1: Deploy LXC with Docker
phase1: init
	@$(PYTHON_VENV) scripts/deploy.py phase1

# Phase 2: Deploy Infisical containers
phase2: init
	@$(PYTHON_VENV) scripts/deploy.py phase2

# Bootstrap Infisical
bootstrap: init
	@$(PYTHON_VENV) scripts/deploy.py bootstrap

# Full apply (intelligent)
apply: init lint
	@$(PYTHON_VENV) scripts/deploy.py apply

# Destroy everything
destroy:
	@$(PYTHON_VENV) scripts/deploy.py destroy 2>/dev/null || terraform destroy -auto-approve

# Clean temporary files
clean:
	rm -rf .terraform
	rm -rf $(VENV)
	rm -rf __pycache__ scripts/__pycache__
	rm -f .terraform.lock.hcl
	rm -f tfplan *.backup
	rm -f *.auto.tfvars
	@echo "==> Cleaned"

