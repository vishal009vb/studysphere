import re
import os
from PyPDF2 import PdfReader
from config import VALID_COURSES, VALID_SUBJECTS, SUBJECT_MAPPINGS, logger

def extract_text_from_pdf(filepath: str, max_pages: int = 3) -> str:
    """Extracts text from the first few pages of a PDF."""
    try:
        reader = PdfReader(filepath)
        text = ""
        for i in range(min(max_pages, len(reader.pages))):
            page_text = reader.pages[i].extract_text()
            if page_text:
                text += page_text + " "
        return text.lower()
    except Exception as e:
        logger.error(f"Failed to extract text from {filepath}: {e}")
        return ""

def classify_pdf(filepath: str) -> dict:
    """
    Classifies a PDF based on its filename and content, returns a metadata dictionary.
    Includes a confidence score.
    """
    filename = os.path.basename(filepath)
    lower_name = filename.lower()
    
    course = None
    subject = None
    doc_type = None
    semester = None
    year = None
    confidence = 100
    
    # 1. Detect Course (Strict Mapping)
    for c in VALID_COURSES:
        if c.lower() in lower_name:
            course = c
            break
            
    if not course:
        course = 'BCA'
        confidence -= 20

    # 2. Detect Semester from filename
    sem_match = re.search(r'sem(?:ester)?\s*[_.-]?\s*(\d)', lower_name)
    if sem_match:
        sem_num = int(sem_match.group(1))
        if 1 <= sem_num <= 8:
            semester = f'Semester {sem_num}'

    # 3. Detect Document Type
    if any(k in lower_name for k in ['pyq', 'paper', 'question']):
        doc_type = 'Paper'
    elif any(k in lower_name for k in ['notes', 'note']):
        doc_type = 'Notes'
    else:
        # Unknown type drops confidence
        confidence -= 20

    # 4. Detect Year
    year_match = re.search(r'(20\d{2})', lower_name)
    if year_match:
        year = year_match.group(1)

    # 5. Extract Subject from filename
    lower_name_parts = re.split(r'[^a-z0-9]+', lower_name)
    
    for main_sub, aliases in SUBJECT_MAPPINGS.items():
        for alias in aliases:
            if len(alias) <= 3:
                if alias in lower_name_parts:
                    subject = main_sub
                    break
            else:
                normalized_alias = re.sub(r'[^a-z0-9]', '', alias.lower())
                if normalized_alias in re.sub(r'[^a-z0-9]', '', lower_name):
                    subject = main_sub
                    break
        if subject:
            break

    # 6. Fallback to PDF Text Analysis if Subject or Semester is missing
    if subject is None or semester is None:
        logger.info(f"Filename lacked info for {filename}. Reading PDF content...")
        pdf_text = extract_text_from_pdf(filepath)
        if pdf_text:
            # Try to find subject in text
            if subject is None:
                pdf_text_parts = re.split(r'[^a-z0-9]+', pdf_text)
                for main_sub, aliases in SUBJECT_MAPPINGS.items():
                    for alias in aliases:
                        if len(alias) <= 3:
                            if alias in pdf_text_parts:
                                subject = main_sub
                                confidence += 30 # Regain some confidence
                                logger.info(f"Found subject '{subject}' in PDF text.")
                                break
                        else:
                            normalized_alias = re.sub(r'[^a-z0-9]', '', alias.lower())
                            if normalized_alias in re.sub(r'[^a-z0-9]', '', pdf_text):
                                subject = main_sub
                                confidence += 30
                                logger.info(f"Found subject '{subject}' in PDF text.")
                                break
                    if subject:
                        break
            
            # Try to find semester in text
            if semester is None:
                sem_match = re.search(r'sem(?:ester)?\s*[_.-]?\s*(\d)', pdf_text)
                if sem_match:
                    sem_num = int(sem_match.group(1))
                    if 1 <= sem_num <= 8:
                        semester = f'Semester {sem_num}'
                        logger.info(f"Found semester '{semester}' in PDF text.")

    if not subject:
        subject = "Unknown Subject"
        confidence -= 50

    # Generate Title
    sem_str = f" {semester}" if semester else ""
    doc_str = f" {doc_type}" if doc_type else " Notes"
    
    if year and doc_type == 'Paper':
        title = f"{subject} {year}{sem_str} PYQ BCA"
    else:
        title = f"{subject}{sem_str}{doc_str} BCA"
        title = " ".join(title.split()) # clean up extra spaces
        
    # Ensure confidence doesn't exceed 100
    confidence = min(100, max(0, confidence))

    return {
        "title": title,
        "course": course,
        "subject": subject,
        "type": doc_type,
        "semester": semester,
        "year": year,
        "confidence": confidence
    }
