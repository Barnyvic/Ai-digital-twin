from pathlib import Path
import json
from pypdf import PdfReader

DATA_DIR = Path(__file__).resolve().parent / "data"

linkedin_path = DATA_DIR / "linkedin.pdf"
if linkedin_path.exists():
    reader = PdfReader(str(linkedin_path))
    linkedin = ""
    for page in reader.pages:
        text = page.extract_text()
        if text:
            linkedin += text
else:
    linkedin = "LinkedIn profile not available"

summary = (DATA_DIR / "summary.txt").read_text(encoding="utf-8")
style = (DATA_DIR / "style.txt").read_text(encoding="utf-8")
facts = json.loads((DATA_DIR / "facts.json").read_text(encoding="utf-8"))
