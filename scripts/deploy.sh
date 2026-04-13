#!/bin/bash
set -e
ENVIRONMENT=${1:-dev}
PROJECT_NAME=${2:-twin}

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
export PATH="$ROOT/tools/bin:$PATH"

(cd backend && python3 deploy.py)

cd terraform
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
terraform init -input=false \
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

terraform apply -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
API_URL=$(terraform output -raw api_gateway_url 2>/dev/null || true)
FRONTEND_BUCKET=$(terraform output -raw s3_frontend_bucket)

cd ../frontend
echo "NEXT_PUBLIC_API_URL=${API_URL:-http://localhost:8000}" > .env.production
npm install
npm run build
aws s3 sync ./out "s3://$FRONTEND_BUCKET/" --delete
