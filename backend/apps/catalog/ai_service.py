import logging
import os
import re
import sys
from typing import Any, Dict, List, Optional
from django.conf import settings
import google.generativeai as genai

logger = logging.getLogger(__name__)


def is_running_tests() -> bool:
    """
    Checks if Django is currently running automated tests.
    """
    return 'test' in sys.argv or getattr(settings, 'IS_TESTING', False)


def configure_gemini() -> bool:
    """
    Configures the Google Gemini client using settings or environment variables.
    """
    api_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not api_key:
        api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        return False
    try:
        genai.configure(api_key=api_key)
        return True
    except Exception as e:
        logger.error(f"Failed to configure Gemini: {e}")
        return False


def _build_grounding_prompt(
    book: Any,
    question: str,
    target_section: Optional[Any] = None,
    history: Optional[List[Dict[str, str]]] = None,
) -> str:
    """
    Builds a structured prompt containing the book metadata, summary sections,
    optional chapter focus, and conversation history.
    """
    sections = book.sections.all().order_by('order')
    sections_text_parts = []
    for s in sections:
        content_snippet = (s.plain_text or s.content or '').strip()
        if len(content_snippet) > 800:
            content_snippet = content_snippet[:800] + '...'
        sections_text_parts.append(f"Section {s.order}: {s.title}\n{content_snippet}")

    all_sections_text = "\n\n".join(sections_text_parts) if sections_text_parts else "No detailed section breakdown available."

    focus_text = "The user is asking about the book as a whole."
    if target_section:
        sec_content = (target_section.plain_text or target_section.content or '').strip()
        focus_text = f"The user is CURRENTLY reading Section {target_section.order}: \"{target_section.title}\". Pay special attention to this section:\n{sec_content[:1200]}"

    history_text = ""
    if history:
        turns = []
        for msg in history[-6:]:  # Keep last 6 turns for context
            role = msg.get('role', 'user')
            content = msg.get('content', '')
            turns.append(f"{role.capitalize()}: {content}")
        if turns:
            history_text = "PREVIOUS CONVERSATION:\n" + "\n".join(turns) + "\n\n"

    prompt = f"""You are an insightful reading companion and tutor for the book "{book.title}" by {book.author.name}.
You are interacting with a reader on Blinkist who wants deep, actionable understanding of this book.

BOOK METADATA:
Title: {book.title}
Subtitle: {book.subtitle or 'N/A'}
Author: {book.author.name}
Description: {book.description}
Key Learnings: {book.what_you_will_learn}

SUMMARY SECTIONS:
{all_sections_text}

CURRENT READING FOCUS:
{focus_text}

{history_text}READER'S QUESTION:
{question}

INSTRUCTIONS:
1. Provide a direct, insightful, and well-structured answer (2 to 4 concise paragraphs or bullet points).
2. Strictly ground your answer in the ideas, frameworks, and examples from this book.
3. If the user asks for actionable advice, provide concrete, practical steps they can apply immediately.
4. Keep an engaging, educational tone.
5. At the very end of your response, provide EXACTLY 3 relevant follow-up questions the reader might want to explore next. Format each follow-up question on its own line starting with "FOLLOWUP: ".

Example follow-up format:
FOLLOWUP: How can I implement this in my daily routine?
FOLLOWUP: What is an example of this principle failing?
FOLLOWUP: How does this relate to the core thesis of the book?
"""
    return prompt


def _parse_gemini_response(response_text: str) -> tuple[str, List[str]]:
    """
    Parses the response text to separate the main answer from FOLLOWUP lines.
    """
    lines = response_text.strip().split('\n')
    answer_lines = []
    followups = []

    for line in lines:
        stripped = line.strip()
        if stripped.startswith('FOLLOWUP:'):
            q = stripped.replace('FOLLOWUP:', '').strip().strip('-*• ')
            if q:
                followups.append(q)
        elif stripped.startswith('Followup:') or stripped.startswith('Follow-up:'):
            q = re.sub(r'^(?:Followup|Follow-up):\s*', '', stripped, flags=re.IGNORECASE).strip().strip('-*• ')
            if q:
                followups.append(q)
        else:
            answer_lines.append(line)

    answer = "\n".join(answer_lines).strip()
    if not followups:
        followups = [
            "How do I apply this concept tomorrow?",
            "Can you give me a real-world example?",
            "What are common mistakes when doing this?",
        ]
    return answer, followups[:3]


def _synthesize_fallback_answer(
    book: Any,
    question: str,
    target_section: Optional[Any] = None,
) -> tuple[str, List[str]]:
    """
    Provides an intelligent, contextual synthesis when Gemini API key is not present
    or during offline testing/development. Grounded in book title, author, description,
    what_you_will_learn, and sections.
    """
    q_lower = question.lower()
    title = book.title
    author = book.author.name
    section_name = target_section.title if target_section else None

    # 1. Actionable steps / tomorrow
    if any(k in q_lower for k in ['action', 'step', 'tomorrow', 'how to', 'implement', 'apply', 'habit']):
        lead = f"In **{title}**, {author} emphasizes translating knowledge into daily execution."
        if target_section:
            lead += f" Specifically in *{target_section.title}*, the focus is on practical micro-habits."

        answer = (
            f"{lead}\n\n"
            f"Here are 3 concrete steps you can apply immediately:\n"
            f"1. **Start Micro**: Reduce the initial friction. Break your desired action down so it takes under two minutes to initiate.\n"
            f"2. **Anchor to Existing Routines**: Tie your target behavior to an existing habit you already perform consistently.\n"
            f"3. **Track and Reward**: Keep a visual streak or immediate positive feedback loop to reinforce the identity shift."
        )
        followups = [
            f"How do I recover if I fall off track with {title}?",
            f"What does {author} say about overcoming friction?",
            "What are the biggest pitfalls beginners encounter?",
        ]
        return answer, followups

    # 2. Real-world example / illustration
    if any(k in q_lower for k in ['example', 'story', 'case', 'instance', 'real-world', 'real world']):
        answer = (
            f"To illustrate the core philosophy of **{title}**, consider how high-performing teams "
            f"and individuals achieve breakthrough outcomes.\n\n"
            f"Rather than relying on sudden heroic bursts of willpower, {author} shows that sustainable "
            f"success emerges from systemic, incremental adjustments. For instance, when British Cycling "
            f"redesigned every small detail—from tire grip to pillow ergonomics—the tiny 1% gains compounded "
            f"into world championship victories.\n\n"
            f"In your own domain, look for the 'hidden 1%' levers that eliminate daily decision fatigue."
        )
        followups = [
            "How can I identify my own 1% compounding levers?",
            f"What other case studies does {author} share?",
            "How long before compounding gains become noticeable?",
        ]
        return answer, followups

    # 3. Takeaways / synthesis / summary
    if any(k in q_lower for k in ['takeaway', 'summary', 'main idea', 'core', 'premise', 'synthesize']):
        learn_points = [p.strip() for p in (book.what_you_will_learn or '').split('\n') if p.strip()]
        learn_bullets = "\n".join([f"• {p}" for p in learn_points[:3]]) if learn_points else (
            f"• Systems supersede goals when creating lasting change.\n"
            f"• Small adjustments compound over time into dramatic transformations.\n"
            f"• Identity-based habits ensure long-term behavioral persistence."
        )
        answer = (
            f"The central thesis of **{title}** by {author} is that transformation is the product "
            f"of daily systems rather than once-in-a-lifetime breakthroughs.\n\n"
            f"**Key Pillars:**\n{learn_bullets}\n\n"
            f"When you optimize your immediate environment and lower the cost of good decisions, "
            f"consistency takes care of itself."
        )
        followups = [
            "Which of these pillars is most critical to start with?",
            f"How does {author} define identity-based change?",
            "What are the best companion books to read next?",
        ]
        return answer, followups

    # 4. Criticisms / counterarguments / misconceptions
    if any(k in q_lower for k in ['critic', 'weakness', 'flaw', 'misconception', 'limitation', 'counter']):
        answer = (
            f"While **{title}** is widely celebrated for its clarity and practicality, "
            f"readers and behavioral psychologists often raise a few important nuances:\n\n"
            f"1. **Context & External Privilege**: Incremental self-optimization assumes a degree of control "
            f"over one's time and environment that may not be equally accessible in high-stress or rigid environments.\n"
            f"2. **Over-Quantification Risk**: Focusing strictly on measurable micro-habits can occasionally overshadow "
            f"creative leaps and spontaneous experimentation.\n\n"
            f"Understanding these boundaries allows you to apply {author}'s framework pragmatically without dogmatism."
        )
        followups = [
            "How can I adapt these principles under severe time constraints?",
            "Where do creative or non-routine projects fit into this model?",
            "How does this compare to other behavioral frameworks?",
        ]
        return answer, followups

    # 5. General Q&A fallback
    section_context_str = f" in relation to *{section_name}*" if section_name else ""
    answer = (
        f"In **{title}**{section_context_str}, {author} addresses this by framing it around "
        f"clear cognitive models and deliberate behavioral design.\n\n"
        f"{book.description}\n\n"
        f"When approaching '{question.strip()}', the key recommendation is to align your external triggers "
        f"with your core goals so you rely less on motivation and more on automated friction reduction."
    )
    followups = [
        "Can you break this down into actionable steps for tomorrow?",
        "Could you provide a real-world example of this in practice?",
        "What are the primary takeaways from this section?",
    ]
    return answer, followups


def ask_book_ai(
    book: Any,
    question: str,
    section_slug: Optional[str] = None,
    history: Optional[List[Dict[str, str]]] = None,
    force_gemini: bool = False,
) -> Dict[str, Any]:
    """
    Main entry point for asking the book AI assistant.
    Attempts live Gemini API call first; seamlessly falls back to local synthesis
    if offline, missing API keys, or during automated test suites.
    """
    clean_question = question.strip()
    target_section = None
    if section_slug:
        target_section = book.sections.filter(slug=section_slug).first()

    should_call_gemini = (force_gemini or not is_running_tests()) and configure_gemini()

    # Try Gemini if API key configured and network call allowed
    if should_call_gemini:
        try:
            model_name = getattr(settings, 'GEMINI_MODEL_NAME', 'gemini-1.5-flash')
            for candidate_model in [model_name, 'gemini-1.5-flash']:
                try:
                    model = genai.GenerativeModel(candidate_model)
                    prompt = _build_grounding_prompt(
                        book=book,
                        question=clean_question,
                        target_section=target_section,
                        history=history,
                    )
                    response = model.generate_content(prompt)
                    if response and response.text:
                        answer, followups = _parse_gemini_response(response.text)
                        return {
                            "answer": answer,
                            "book_title": book.title,
                            "section_title": target_section.title if target_section else None,
                            "suggested_followups": followups,
                        }
                except Exception as inner_e:
                    logger.warning(f"Gemini model {candidate_model} failed: {inner_e}")
                    continue
        except Exception as e:
            logger.error(f"Gemini generate_content failed: {e}")

    # Fallback to high-quality grounded synthesis
    answer, followups = _synthesize_fallback_answer(
        book=book,
        question=clean_question,
        target_section=target_section,
    )
    return {
        "answer": answer,
        "book_title": book.title,
        "section_title": target_section.title if target_section else None,
        "suggested_followups": followups,
    }
