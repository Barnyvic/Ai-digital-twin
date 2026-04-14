#!/bin/bash
set -e
ENVIRONMENT=${1:-dev}
PROJECT_NAME=${2:-twin}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/tools/bin:$PATH"

# github_repository (required by terraform/github-oidc.tf): env GITHUB_REPOSITORY, third CLI arg, or git origin
GITHUB_REPO="${GITHUB_REPOSITORY:-${3:-}}"
if [ -z "$GITHUB_REPO" ] && url=$(git -C "$ROOT" remote get-url origin 2>/dev/null); then
  case "$url" in
    git@github.com:*) GITHUB_REPO="${url#git@github.com:}" ;;
    https://github.com/*) GITHUB_REPO="${url#https://github.com/}" ;;
  esac
  GITHUB_REPO="${GITHUB_REPO%.git}"
fi
if [ -z "$GITHUB_REPO" ]; then
  echo "Set GITHUB_REPOSITORY=owner/repo, pass it as third argument, or add git remote origin." >&2
  exit 1
fi

# Set SKIP_LAMBDA_BUILD=1 to skip Docker repackaging when backend/lambda-deployment.zip is already built
if [ "${SKIP_LAMBDA_BUILD:-0}" = "1" ]; then
  echo "Skipping Lambda build (SKIP_LAMBDA_BUILD=1)"
else
  (cd backend && python3 deploy.py)
fi

cd terraform
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
# When providers are already under .terraform/providers, use them and skip registry.terraform.io
# (fixes TLS timeout / offline installs). Omit if you need a fresh provider download.
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

if ! terraform workspace list | grep -q "$ENVIRONMENT"; then
  terraform workspace new "$ENVIRONMENT"
else
  terraform workspace select "$ENVIRONMENT"
fi

terraform apply \
  -var="project_name=$PROJECT_NAME" \
  -var="environment=$ENVIRONMENT" \
  -var="github_repository=$GITHUB_REPO" \
  -auto-approve
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || true)
FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)

cd ../frontend
# Prefer Homebrew Node if present, because old nvm Node can break Next.js builds.
if [ -x "/opt/homebrew/bin/node" ]; then
  export PATH="/opt/homebrew/bin:$PATH"
fi
NODE_MAJOR=$(node -v 2>/dev/null | sed -E 's/^v([0-9]+).*/\1/')
if [ -z "$NODE_MAJOR" ] || [ "$NODE_MAJOR" -lt 20 ]; then
  echo "Node.js >= 20 is required for frontend build. Current: $(node -v 2>/dev/null || echo unavailable)" >&2
  exit 1
fi
echo "NEXT_PUBLIC_API_URL=${API_URL:-http://localhost:8000}" > .env.production
npm install
npm run build
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete
