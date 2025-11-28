# Infisical Bootstrap
# 
# Bootstrap is handled by deploy.py Phase 3 (not Terraform).
# This is because null_resource.local-exec cannot capture script output.
# The bootstrap credentials are passed to Terraform via TF_VAR_* environment variables.
#
# See: scripts/deploy.py bootstrap() method


