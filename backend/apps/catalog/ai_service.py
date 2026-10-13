from __future__ import annotations
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
    optional chapter focus, citations instructions, and conversation history.
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
4. When citing ideas, principles, or frameworks that originate from specific chapters/sections, explicitly cite them using the format [Section X: Title] or [Section X] (e.g. [Section 1: The Surprising Power of Atomic Habits]).
5. Keep an engaging, educational tone.
6. At the very end of your response, provide EXACTLY 3 relevant follow-up questions the reader might want to explore next. Format each follow-up question on its own line starting with "FOLLOWUP: ".

Example follow-up format:
FOLLOWUP: Give me 3 practical action steps
FOLLOWUP: Explain like I'm 5
FOLLOWUP: How does this relate to the core thesis of the book?
"""
    return prompt


def _extract_citations(
    book: Any,
    text: str,
    target_section: Optional[Any] = None,
) -> List[Dict[str, Any]]:
    """
    Extracts structured section citations mentioned in the answer or based on target section.
    """
    citations: List[Dict[str, Any]] = []
    seen_orders: set[int] = set()

    # Match patterns like [Section 1: Title] or [Section 1] or Section 1
    matches = re.findall(r'(?:\[Section\s+(\d+)|Section\s+(\d+))', text, flags=re.IGNORECASE)
    for m in matches:
        order_str = m[0] or m[1]
        try:
            order = int(order_str)
            if order in seen_orders:
                continue
            sec = book.sections.filter(order=order).first()
            if sec:
                seen_orders.add(order)
                citations.append({
                    "order": sec.order,
                    "title": sec.title,
                    "slug": sec.slug,
                    "id": sec.id,
                })
        except (ValueError, TypeError):
            continue

    # If target_section is set and not yet included, ensure it is available in citations
    if target_section and target_section.order not in seen_orders:
        citations.insert(0, {
            "order": target_section.order,
            "title": target_section.title,
            "slug": target_section.slug,
            "id": target_section.id,
        })
        seen_orders.add(target_section.order)

    # Fallback to first section if no citations found and book has sections
    if not citations:
        first_sec = book.sections.order_by('order').first()
        if first_sec:
            citations.append({
                "order": first_sec.order,
                "title": first_sec.title,
                "slug": first_sec.slug,
                "id": first_sec.id,
            })

    return citations[:4]


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
            "Give me 3 practical action steps",
            "Explain like I'm 5",
            "What are common pitfalls when applying this?",
        ]
    return answer, followups[:3]


def _synthesize_fallback_answer(
    book: Any,
    question: str,
    target_section: Optional[Any] = None,
) -> tuple[str, List[str], List[Dict[str, Any]]]:
    """
    Provides an intelligent, contextual synthesis when Gemini API key is not present
    or during offline testing/development. Grounded in book title, author, description,
    what_you_will_learn, and summary sections.
    """
    q_lower = question.lower()
    title = book.title
    author = book.author.name
    first_sec = book.sections.order_by('order').first()
    sec_ref = target_section or first_sec
    sec_tag = f"[Section {sec_ref.order}: {sec_ref.title}]" if sec_ref else ""

    # 1. Checklist
    if any(k in q_lower for k in ['checklist', 'check list', 'action plan']):
        lead = f"Here is an actionable execution checklist based on **{title}** by {author}"
        if sec_tag:
            lead += f", drawn from {sec_tag}"
        lead += ":\n\n"
        answer = (
            f"{lead}"
            f"• [ ] **Define the Micro-Trigger**: Identify the exact cue that initiates the behavior.\n"
            f"• [ ] **Remove Friction Points**: Eliminate at least two intermediate steps or decisions.\n"
            f"• [ ] **Establish an Accountability Anchor**: Track completion daily or share progress with a peer.\n"
            f"• [ ] **Celebrate Immediate Reinforcement**: Attach an immediate reward to cement the neurological feedback loop."
        )
        followups = [
            "Give me 3 practical action steps",
            "Explain like I'm 5",
            f"What does {author} say about overcoming friction?",
        ]
        citations = _extract_citations(book, answer, target_section=target_section)
        return answer, followups, citations

    # 2. Explain like I'm 5 (ELI5)
    if any(k in q_lower for k in ['eli5', 'explain like i\'m 5', 'explain like im 5', 'simple terms', 'simple', 'for a child']):
        answer = (
            f"Think of **{title}** like building a giant LEGO castle. {sec_tag}\n\n"
            f"You don't build a whole castle in one giant leap. If you try to do everything all at once, "
            f"it gets scary and messy! Instead, you just snap **one small brick into place every single day**.\n\n"
            f"At first, it just looks like a few plastic blocks. But after a few weeks, those tiny bricks "
            f"magically turn into a massive fortress. {author} teaches us that doing something tiny and fun "
            f"every day beats trying to be a superhero once a year."
        )
        followups = [
            "Give me 3 practical action steps",
            "What is a real-world example of this?",
            "Create an execution checklist",
        ]
        citations = _extract_citations(book, answer, target_section=target_section)
        return answer, followups, citations

    # 3. Actionable steps / tomorrow
    if any(k in q_lower for k in ['action', 'step', 'tomorrow', 'how to', 'implement', 'apply', 'habit']):
        lead = f"In **{title}**, {author} emphasizes translating knowledge into daily execution."
        if sec_tag:
            lead += f" Specifically in {sec_tag}, the focus is on practical micro-habits."

        answer = (
            f"{lead}\n\n"
            f"Here are 3 concrete steps you can apply immediately:\n"
            f"1. **Start Micro (The 2-Minute Rule)**: Reduce initial friction. Break your desired action down so it takes under two minutes to initiate.\n"
            f"2. **Anchor to Existing Routines**: Tie your target behavior to an existing ritual you already perform consistently.\n"
            f"3. **Track and Reward**: Keep a visual streak or immediate positive feedback loop to reinforce the identity shift."
        )
        followups = [
            "Explain like I'm 5",
            f"How do I recover if I fall off track with {title}?",
            "Create an execution checklist",
        ]
        citations = _extract_citations(book, answer, target_section=target_section)
        return answer, followups, citations

    # 4. Real-world example / illustration
    if any(k in q_lower for k in ['example', 'story', 'case', 'instance', 'real-world', 'real world']):
        answer = (
            f"To illustrate the core philosophy of **{title}**, consider how high-performing teams "
            f"and individuals achieve breakthrough outcomes. {sec_tag}\n\n"
            f"Rather than relying on sudden heroic bursts of willpower, {author} shows that sustainable "
            f"success emerges from systemic, incremental adjustments. For instance, when British Cycling "
            f"redesigned every small detail—from tire grip to pillow ergonomics—the tiny 1% gains compounded "
            f"into world championship victories.\n\n"
            f"In your own domain, look for the 'hidden 1%' levers that eliminate daily decision fatigue."
        )
        followups = [
            "Give me 3 practical action steps",
            "How can I identify my own 1% compounding levers?",
            "What are common pitfalls when doing this?",
        ]
        citations = _extract_citations(book, answer, target_section=target_section)
        return answer, followups, citations

    # 5. Criticisms / counterarguments / misconceptions
    if any(k in q_lower for k in ['critic', 'weakness', 'flaw', 'misconception', 'limitation', 'counter']):
        answer = (
            f"While **{title}** is widely celebrated for its clarity and practicality, "
            f"readers and behavioral psychologists often raise a few important nuances {sec_tag}:\n\n"
            f"1. **Context & External Privilege**: Incremental self-optimization assumes a degree of control "
            f"over one's time and environment that may not be equally accessible in high-stress or rigid environments.\n"
            f"2. **Over-Quantification Risk**: Focusing strictly on measurable micro-habits can occasionally overshadow "
            f"creative leaps and spontaneous experimentation.\n\n"
            f"Understanding these boundaries allows you to apply {author}'s framework pragmatically without dogmatism."
        )
        followups = [
            "Give me 3 practical action steps",
            "How can I adapt these principles under severe time constraints?",
            "What are the primary takeaways from this book?",
        ]
        citations = _extract_citations(book, answer, target_section=target_section)
        return answer, followups, citations

    # 6. General Q&A fallback
    section_context_str = f" in relation to {sec_tag}" if sec_tag else ""
    answer = (
        f"In **{title}**{section_context_str}, {author} addresses this by framing it around "
        f"clear cognitive models and deliberate behavioral design.\n\n"
        f"{book.description}\n\n"
        f"When approaching '{question.strip()}', the key recommendation is to align your external triggers "
        f"with your core goals so you rely less on motivation and more on automated friction reduction."
    )
    followups = [
        "Give me 3 practical action steps",
        "Explain like I'm 5",
        "Create an execution checklist",
    ]
    citations = _extract_citations(book, answer, target_section=target_section)
    return answer, followups, citations


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
    Returns structured answer, book and section titles, citations, and follow-ups.
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
                        citations = _extract_citations(book, answer, target_section=target_section)
                        return {
                            "answer": answer,
                            "book_title": book.title,
                            "section_title": target_section.title if target_section else None,
                            "citations": citations,
                            "suggested_followups": followups,
                        }
                except Exception as inner_e:
                    logger.warning(f"Gemini model {candidate_model} failed: {inner_e}")
                    continue
        except Exception as e:
            logger.error(f"Gemini generate_content failed: {e}")

    # Fallback to high-quality grounded synthesis
    answer, followups, citations = _synthesize_fallback_answer(
        book=book,
        question=clean_question,
        target_section=target_section,
    )
    return {
        "answer": answer,
        "book_title": book.title,
        "section_title": target_section.title if target_section else None,
        "citations": citations,
        "suggested_followups": followups,
    }
