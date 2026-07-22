import os
import logging
from dotenv import load_dotenv

# Load env variables from a .env file if present
load_dotenv()

# Directories
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
LOGS_DIR = os.path.join(BASE_DIR, 'logs')
DOWNLOADS_DIR = os.path.join(BASE_DIR, 'downloads')

os.makedirs(LOGS_DIR, exist_ok=True)
os.makedirs(DOWNLOADS_DIR, exist_ok=True)

# Logging Setup
log_format = '%(asctime)s - %(levelname)s - %(module)s - %(message)s'
logging.basicConfig(
    level=logging.INFO,
    format=log_format,
    handlers=[
        logging.FileHandler(os.path.join(LOGS_DIR, 'scraper.log')),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger(__name__)

# Trusted Domains
TRUSTED_DOMAINS = [
    '.gov.in',
    '.ac.in',
    '.edu',
    'ignou.ac.in',
    'nmu.ac.in',
    'nptel.ac.in',
    'w3.org',
    '.com',
    '.org',
    '.net',
    '.in',
    '.edu',
    '.co.in',
    '.ac.uk',
    '.info',
    '.io',
    '.co'
]

def is_trusted_domain(url: str) -> bool:
    from urllib.parse import urlparse
    domain = urlparse(url).netloc.lower()
    return any(domain.endswith(trusted) for trusted in TRUSTED_DOMAINS)

# Allowed Courses (Strict Mapping)
VALID_COURSES = ['BCA', 'BBA', 'BSc', 'BCom', 'MCA', 'Polytechnic', 'MPSC', 'UPSC']

# Allowed Subjects and Aliases for robust classification
SUBJECT_MAPPINGS = {
    'Mathematics': ['math', 'maths', 'mathematics', 'ca124'],
    'Computer Networks': ['network', 'networking', 'cn'],
    'Software Engineering': ['se', 'software engineering'],
    'Data Structures': ['ds', 'data structure'],
    'Operating Systems': ['os', 'operating system', 'ca122'],
    'Database Management': ['dbms', 'database'],
    'Web Technology': ['web', 'web design', 'ca125'],
    'General Studies': ['general studies', 'gs'],
    'C++ Programming': ['cpp', 'c++', 'oop', 'oops', 'opps', 'ca112', 'ca121'],
    'Python Programming': ['python'],
    'Ethical Hacking': ['hacking', 'ethical hacking', 'ca217', 'ca-217'],
    'Environmental Studies': ['evs', 'environmental', 'environment'],
    'Graphics Design': ['graphic', 'graphics', 'ca126', 'ca227'],
    'English': ['english'],
    'Marathi': ['marathi'],
    'Constitution': ['constitution'],
    'JavaScript': ['javascript', 'js'],
    'Microprocessor': ['microprocessor', 'micro'],
    'Essential of Computers': ['essential of computers', 'ca111', 'essential of computer'],
    'Office Management Tools': ['office management', 'ca114'],
    'Artificial Intelligence': ['ai', 'artificial intelligence', 'ca222'],
    'Employability Skills': ['employability', 'bca501'],
    'E-Commerce': ['e-commerce', 'm-commerce', 'ecommerce', 'bca502', 'bca505'],
    'Cloud Computing': ['cloud computing', 'bca503', 'bca506'],
    'Web Development': ['web development', 'web dev', 'bca504', 'bca604'],
    'Data Analytics': ['data analytics', 'bca504', 'bca604'],
    'Machine Learning': ['machine learning', 'ml', 'bca504', 'bca507'],
    'Entrepreneurship Development': ['entrepreneurship', 'bca601'],
    'Cyber Security': ['cyber security', 'bca602'],
    'Android Development': ['android', 'bca603', 'bca606'],
    'Data Mining': ['data mining', 'bca604', 'bca607']
}
VALID_SUBJECTS = list(SUBJECT_MAPPINGS.keys())

# Firebase Config
FIREBASE_SERVICE_BASE_DIR = os.path.dirname(__file__)
FIREBASE_SERVICE_ACCOUNT = os.path.join(BASE_DIR, 'serviceAccountKey.json')

# Supabase Storage Config
SUPABASE_URL = os.environ.get('SUPABASE_URL')
SUPABASE_ANON_KEY = os.environ.get('SUPABASE_ANON_KEY')

# Search API Keys (You can add your additional free API keys here)
SERPAPI_KEYS = [
    os.environ.get('SERPAPI_KEY', 'addee223100ddea0794a7c782e22353dd1f20d2e9d7ff147fcd1a8518e6cfbcd'),
    # 'YOUR_SECOND_FREE_API_KEY_HERE',
]

# Google Custom Search API (Recommended - 100 free queries/day)
GOOGLE_API_KEY = os.environ.get('GOOGLE_API_KEY', 'AIzaSyAGE0u--1UmcLUTjCH2CKDZ-Qdsq8YfCHk')
GOOGLE_CX = os.environ.get('GOOGLE_CX', 'a09489c1e84af4e8f')
