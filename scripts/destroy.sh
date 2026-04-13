#!/bin/bash
set -e
ENVIRONMENT=$1
PROJECT_NAME=${2:-twin}
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PATH="$ROOT/tools/bin:$PATH"
cd "$ROOT/terraform"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION=${DEFAULT_AWS_REGION:-us-east-1}
terraform init -input=false \
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
terraform destroy -var="project_name=$PROJECT_NAME" -var="environment=$ENVIRONMENT" -auto-approve
