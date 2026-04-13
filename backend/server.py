from datetime import datetime
import json
import os
import uuid
from typing import Dict, List, Optional

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from context import prompt

load_dotenv()

app = FastAPI(title="AI Digital Twin API")

origins = os.getenv("CORS_ORIGINS", "http://localhost:3000").split(",")
app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

bedrock_client = boto3.client(
    service_name="bedrock-runtime",
    region_name=os.getenv("DEFAULT_AWS_REGION", "us-east-1"),
)

BEDROCK_MODEL_ID = os.getenv("BEDROCK_MODEL_ID", "global.amazon.nova-2-lite-v1:0")
USE_S3 = os.getenv("USE_S3", "false").lower() == "true"
S3_BUCKET = os.getenv("S3_BUCKET", "")
MEMORY_DIR = os.getenv("MEMORY_DIR", "../memory")

s3_client = boto3.client("s3") if USE_S3 else None


class ChatRequest(BaseModel):
    message: str
    session_id: Optional[str] = None


class ChatResponse(BaseModel):
    response: str
    session_id: str


def _memory_key(session_id: str) -> str:
    return f"{session_id}.json"


def load_conversation(session_id: str) -> List[Dict]:
    if USE_S3:
        try:
            resp = s3_client.get_object(Bucket=S3_BUCKET, Key=_memory_key(session_id))
            return json.loads(resp["Body"].read().decode("utf-8"))
        except ClientError as exc:
            if exc.response.get("Error", {}).get("Code") == "NoSuchKey":
                return []
            raise

    os.makedirs(MEMORY_DIR, exist_ok=True)
    file_path = os.path.join(MEMORY_DIR, _memory_key(session_id))
    if os.path.exists(file_path):
        with open(file_path, "r", encoding="utf-8") as f:
            return json.load(f)
    return []


def save_conversation(session_id: str, messages: List[Dict]) -> None:
    if USE_S3:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=_memory_key(session_id),
            Body=json.dumps(messages, indent=2),
            ContentType="application/json",
        )
        return

    os.makedirs(MEMORY_DIR, exist_ok=True)
    file_path = os.path.join(MEMORY_DIR, _memory_key(session_id))
    with open(file_path, "w", encoding="utf-8") as f:
        json.dump(messages, f, indent=2)


def call_bedrock(conversation: List[Dict], user_message: str) -> str:
    messages = [{"role": "user", "content": [{"text": f"System: {prompt()}"}]}]

    for msg in conversation[-50:]:
        messages.append({"role": msg["role"], "content": [{"text": msg["content"]}]})

    messages.append({"role": "user", "content": [{"text": user_message}]})

    try:
        response = bedrock_client.converse(
            modelId=BEDROCK_MODEL_ID,
            messages=messages,
            inferenceConfig={"maxTokens": 1200, "temperature": 0.7, "topP": 0.9},
        )
        return response["output"]["message"]["content"][0]["text"]
    except ClientError as exc:
        code = exc.response["Error"].get("Code", "Unknown")
        raise HTTPException(status_code=500, detail=f"Bedrock error ({code})") from exc


@app.get("/")
async def root():
    return {"message": "AI Digital Twin API", "model": BEDROCK_MODEL_ID}


@app.get("/health")
async def health():
    return {"status": "healthy", "use_s3": USE_S3, "model": BEDROCK_MODEL_ID}


@app.post("/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    try:
        session_id = request.session_id or str(uuid.uuid4())
        conversation = load_conversation(session_id)
        answer = call_bedrock(conversation, request.message)

        conversation.append({"role": "user", "content": request.message, "timestamp": datetime.now().isoformat()})
        conversation.append({"role": "assistant", "content": answer, "timestamp": datetime.now().isoformat()})
        save_conversation(session_id, conversation)

        return ChatResponse(response=answer, session_id=session_id)
    except HTTPException:
        raise
    except Exception as exc:
        raise HTTPException(status_code=500, detail=str(exc)) from exc


@app.get("/conversation/{session_id}")
async def get_conversation(session_id: str):
    return {"session_id": session_id, "messages": load_conversation(session_id)}
