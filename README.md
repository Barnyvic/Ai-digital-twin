# AI Digital Twin (Week 1-5 Starter)

This repository gives you a full starter to build and deploy your own AI Digital Twin:
- Next.js + Tailwind frontend
- FastAPI backend with conversation memory
- AWS Bedrock model integration
- Terraform infrastructure folder
- GitHub Actions deploy/destroy workflows

## Local quick start

### Backend
1. `cd backend`
2. Create `.env` with: `CORS_ORIGINS=http://localhost:3000`, `DEFAULT_AWS_REGION=us-east-1`, `BEDROCK_MODEL_ID=global.amazon.nova-2-lite-v1:0`
3. `uv init --bare`
4. `uv python pin 3.12`
5. `uv add -r requirements.txt`
6. `uv run uvicorn server:app --reload`

### Frontend
1. `cd frontend`
2. `npm install`
3. `npm run dev`
4. Open `http://localhost:3000`

## Notes
- Add your real profile data in `backend/data/*` and optional `backend/data/linkedin.pdf`.
- For CI/CD, add repository secrets: `AWS_ROLE_ARN`, `DEFAULT_AWS_REGION`, `AWS_ACCOUNT_ID`.
