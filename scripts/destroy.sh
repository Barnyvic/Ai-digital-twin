#!/bin/bash
set -e
ENVIRONMENT=$1
PROJECT_NAME=${2:-twin}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/tools/bin:$PATH"

GITHUB_REPO="${GITHUB_REPOSITORY:-${3:-}}"
if [ -z "$GITHUB_REPO" ] && url=$(git -C "$ROOT" remote get-url origin 2>/dev/null); then
  case "$url" in
    git@github.com:*) GITHUB_REPO="${url#git@github.com:}" ;;
    https://github.com/*) GITHUB_REPO="${url#https://github.com/}" ;;
  esac
  GITHUB_REPO="${GITHUB_REPO%.git}"
fi
if [ -z "$GITHUB_REPO" ]; then
  echo "Set GITHUB_REPOSITORY=owner/repo, pass as third argument, or add git remote origin." >&2
  exit 1
fi

cd "$ROOT/terraform"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
TF_INIT_EXTRA=()
if [ -d ".terraform/providers/registry.terraform.io" ]; then
  TF_INIT_EXTRA=(-plugin-dir "$(pwd)/.terraform/providers")
fi
terraform init -input=false \
  "${TF_INIT_EXTRA[@]}" \
  -backend-config="bucket=twin-terraform-state-${AWS_ACCOUNT_ID}" \
  -backend-config="key=${ENVIRONMENT}/terraform.tfstate" \
  -backend-config="region=${AWS_REGION}" \
  -backend-config="dynamodb_table=twin-terraform-locks" \
  -backend-config="encrypt=true"
terraform workspace select "$ENVIRONMENT"
aws s3 rm "s3://${PROJECT_NAME}-${ENVIRONMENT}-frontend-${AWS_ACCOUNT_ID}" --recursive || true
aws s3 rm "s3://${PROJECT_NAME}-${ENVIRONMENT}-memory-${AWS_ACCOUNT_ID}" --recursive || true
if [ ! -f "../backend/lambda-deployment.zip" ]; then
  python3 - <<'PY'
import zipfile
with zipfile.ZipFile('../backend/lambda-deployment.zip','w') as z:
    z.writestr('dummy.txt','dummy')
PY
fi
terraform destroy \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="github_repository=$GITHUB_REPO" \
  -auto-approve
