import logging
import os
from django.conf import settings
import google.generativeai as genai
from pinecone import Pinecone

logger = logging.getLogger(__name__)

def configure_gemini():
    api_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not api_key:
        api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        return False
    genai.configure(api_key=api_key)
    return True

def get_pinecone_client():
    api_key = getattr(settings, 'PINECONE_API_KEY', '')
    if not api_key:
        return None
    return Pinecone(api_key=api_key)

def get_book_embedding(text):
    """
    Get embedding for book text using Google Gemini.
    Model: models/text-embedding-004 (768 dimensions)
    Note: Pinecone index must be configured for 768 dimensions.
    """
    if not configure_gemini():
        logger.error("Gemini API key not set.")
        return None
        
    try:
        result = genai.embed_content(
            model="models/text-embedding-004",
            content=text,
            task_type="retrieval_document",
            title="Book Recommendation"
        )
        return result['embedding']
    except Exception as e:
        logger.error(f"Failed to get Gemini embedding: {e}")
        return None

def upsert_book_vector(book_id, vector):
    """
    Upsert book vector to Pinecone.
    """
    pc = get_pinecone_client()
    if not pc:
        logger.warning("Pinecone API key not set. Skipping upsert.")
        return False
    
    index_name = getattr(settings, 'PINECONE_INDEX_NAME', 'blinkist-clone')
    try:
        index = pc.Index(index_name)
        index.upsert(
            vectors=[
                {
                    "id": str(book_id),
                    "values": vector,
                    "metadata": {"book_id": book_id}
                }
            ]
        )
        return True
    except Exception as e:
        logger.error(f"Failed to upsert to Pinecone: {e}")
        return False

def query_similar_books(vector, top_k=10):
    """
    Query Pinecone for similar books.
    """
    pc = get_pinecone_client()
    if not pc:
        return []
    
    index_name = getattr(settings, 'PINECONE_INDEX_NAME', 'blinkist-clone')
    try:
        index = pc.Index(index_name)
        results = index.query(
            vector=vector,
            top_k=top_k,
            include_metadata=True
        )
        return [int(match['metadata']['book_id']) for match in results['matches']]
    except Exception as e:
        logger.error(f"Failed to query Pinecone: {e}")
        return []
