from __future__ import annotations

import json
import logging
import os
import re
import sys
from datetime import datetime, timedelta
from typing import Any, Dict, List, Optional
from django.conf import settings
from django.db import transaction
from django.utils import timezone
import google.generativeai as genai

from apps.catalog.models import Book
from apps.summaries.models import SummarySection, UserHighlight
from apps.progress.models import ActionPlan, ActionPlanItem

logger = logging.getLogger(__name__)


def is_running_tests() -> bool:
    return 'test' in sys.argv or getattr(settings, 'IS_TESTING', False)


def configure_gemini() -> bool:
    api_key = getattr(settings, 'GEMINI_API_KEY', None)
    if not api_key:
        api_key = os.environ.get('GEMINI_API_KEY')
    if not api_key:
        return False
    try:
        genai.configure(api_key=api_key)
        return True
    except Exception as e:
        logger.error(f"Failed to configure Gemini for ActionPlan: {e}")
        return False


def _build_action_plan_prompt(
    book: Book,
    duration_days: int,
    user_highlights: List[Dict[str, str]],
) -> str:
    sections = book.sections.all().order_by('order')
    sections_text_parts = []
    for s in sections:
        content_snippet = (s.plain_text or s.content or '').strip()
        if len(content_snippet) > 600:
            content_snippet = content_snippet[:600] + '...'
        sections_text_parts.append(f"Section {s.order}: {s.title}\n{content_snippet}")

    all_sections = "\n\n".join(sections_text_parts) if sections_text_parts else "No sections available."

    highlights_text = "No user highlights saved."
    if user_highlights:
        formatted_hl = []
        for i, hl in enumerate(user_highlights[:10], 1):
            text = hl.get('text', '').strip()
            note = hl.get('note', '').strip()
            item_str = f"Highlight #{i}: \"{text}\""
            if note:
                item_str += f" (User Margin Note: \"{note}\")"
            formatted_hl.append(item_str)
        highlights_text = "\n".join(formatted_hl)

    prompt = f"""You are an elite behavioral scientist, habit architect, and executive coach.
Your task is to synthesize a structured, high-impact {duration_days}-Day Micro-Habit Roadmap & Action Plan for the book "{book.title}" by {book.author.name}.

BOOK INFORMATION:
Title: {book.title}
Author: {book.author.name}
Subtitle: {book.subtitle or 'N/A'}
Core Learnings: {book.what_you_will_learn}

BOOK CHAPTER SECTIONS:
{all_sections}

USER'S PERSONAL SAVED HIGHLIGHTS & NOTES:
{highlights_text}

INSTRUCTIONS:
1. Synthesize exactly {duration_days} consecutive daily micro-habits (Day 1 through Day {duration_days}).
2. Ground each day's step deeply in the core mental models and frameworks of "{book.title}".
3. If the user saved highlights or notes, explicitly weave the user's highlighted concepts into the action steps.
4. Each day must be practical, taking 2 to 5 minutes to execute in real life.
5. Provide the output strictly as a JSON array of objects with the following schema:
[
  {{
    "day_number": 1,
    "title": "Short punchy action title (e.g. Audit Your Cue Environment)",
    "description": "2-3 clear sentences explaining what to do, why it works based on the book, and how to apply it.",
    "suggested_habit": "Concrete implementation intention (e.g. 'When I pour my morning coffee, I will write down my 1 primary objective for today.')",
    "associated_quote": "A poignant quote or principle from the book or from the user's highlights."
  }}
]

Return ONLY the raw JSON array. Do not add markdown introductory or conversational text.
"""
    return prompt


def _generate_fallback_items(
    book: Book,
    duration_days: int,
    user_highlights: List[Dict[str, str]],
) -> List[Dict[str, Any]]:
    """
    High-quality deterministic fallback action plan generator when AI is offline.
    Intelligently cycles through book chapters and weaves in user highlights.
    """
    sections = list(book.sections.all().order_by('order'))
    items: List[Dict[str, Any]] = []

    framework_verbs = [
        ("Audit & Baseline", "Establish clarity and inspect current cues and defaults"),
        ("Micro-Commitment Setup", "Design the 2-minute version of the core behavior"),
        ("Friction Reduction", "Remove physical and digital obstacles to execution"),
        ("Habit Stacking", "Anchor the new routine directly onto an existing automatic ritual"),
        ("Implementation Intention", "Formulate an exact 'When [Trigger], Then [Action]' statement"),
        ("Environment Architecture", "Optimize visual cues in your workspace and living space"),
        ("Accountability & Feedback", "Establish a tracking mechanism to make progress visible"),
        ("Identity Alignment", "Shift focus from outcome-based goals to identity-based standards"),
        ("Temptation Bundling", "Pair a necessary discipline with an immediately rewarding experience"),
        ("Plateau Defense", "Prepare pre-planned responses for low-energy and high-stress moments"),
        ("Social Environment Design", "Curate peer cues and communicate boundary commitments"),
        ("Reflection & Calibration", "Review what produced exponential results vs friction"),
        ("System Automation", "Delegate, automate, or lock in recurring positive defaults"),
        ("Mastery & Compounding", "Scale the habit and integrate lifelong continuous refinement"),
    ]

    for day in range(1, duration_days + 1):
        verb, verb_desc = framework_verbs[(day - 1) % len(framework_verbs)]
        
        # Pull section if available
        sec = sections[(day - 1) % len(sections)] if sections else None
        sec_title = sec.title if sec else f"Core Principle #{day}"
        sec_snippet = ""
        if sec:
            raw_text = (sec.plain_text or sec.content or "").strip()
            if raw_text:
                sec_snippet = raw_text[:140].replace("\n", " ") + "..."

        # Check if we can assign a user highlight to this day
        quote = ""
        user_hl_assigned = False
        if user_highlights and (day - 1) < len(user_highlights):
            hl_data = user_highlights[day - 1]
            quote = f"\"{hl_data.get('text', '')}\""
            if hl_data.get('note'):
                quote += f" — Personal note: {hl_data.get('note')}"
            user_hl_assigned = True
        elif sec_snippet:
            quote = f"\"{sec_snippet}\" — {book.title}"
        else:
            quote = f"\"Small disciplines repeated with consistency yield massive transformation.\" — {book.author.name}"

        # Build day title and description
        if user_hl_assigned:
            title = f"Day {day}: {verb} — {sec_title}"
            desc = (
                f"{verb_desc} with direct reference to your personal highlight. "
                f"Apply the insight from '{sec_title}' to eliminate friction in your daily routine."
            )
        else:
            title = f"Day {day}: {verb} ({sec_title})"
            desc = (
                f"{verb_desc}. Grounded in '{sec_title}', dedicate 3 minutes today "
                f"to establish a tangible micro-action that reinforces this principle."
            )

        suggested_habit = f"When I begin my morning routine on Day {day}, I will implement 1 concrete step from '{sec_title}' for 2 minutes."

        items.append({
            "day_number": day,
            "title": title,
            "description": desc,
            "suggested_habit": suggested_habit,
            "associated_quote": quote,
        })

    return items


class ActionPlanService:
    @staticmethod
    def generate_plan(
        user: Any,
        book: Book,
        duration_days: int = 7,
        force_regenerate: bool = False,
    ) -> ActionPlan:
        """
        Synthesizes or retrieves a structured ActionPlan for a user and book.
        Merges the user's highlights and margin notes.
        """
        if duration_days not in (7, 14):
            duration_days = 7

        existing = ActionPlan.objects.filter(
            user=user,
            book=book,
            duration_days=duration_days,
            is_active=True,
        ).first()

        if existing and not force_regenerate:
            return existing

        # Fetch user highlights and margin notes for this book
        highlights_qs = UserHighlight.objects.filter(
            user=user,
            book=book,
        ).order_by('-created_at')

        user_highlights = []
        for hl in highlights_qs:
            user_highlights.append({
                'text': getattr(hl, 'selected_text', '') or getattr(hl, 'highlighted_text', ''),
                'note': hl.note or '',
                'section_order': hl.section.order if hl.section else None,
            })

        items_data: List[Dict[str, Any]] = []

        if not is_running_tests() and configure_gemini():
            try:
                model = genai.GenerativeModel('gemini-2.5-flash')
                prompt = _build_action_plan_prompt(book, duration_days, user_highlights)
                response = model.generate_content(
                    prompt,
                    generation_config={"response_mime_type": "application/json"}
                )
                text = (response.text or "").strip()
                if text.startswith("```"):
                    text = re.sub(r"^```(?:json)?\n?", "", text)
                    text = re.sub(r"\n?```$", "", text)
                parsed = json.loads(text)
                if isinstance(parsed, list) and len(parsed) >= duration_days:
                    items_data = parsed[:duration_days]
            except Exception as e:
                logger.warning(f"Gemini ActionPlan generation failed, falling back to local synthesis: {e}")

        if not items_data:
            items_data = _generate_fallback_items(book, duration_days, user_highlights)

        with transaction.atomic():
            if existing:
                existing.items.all().delete()
                plan = existing
                plan.title = f"{book.title}: {duration_days}-Day Habit Roadmap"
                plan.save(update_fields=['title', 'updated_at'])
            else:
                plan = ActionPlan.objects.create(
                    user=user,
                    book=book,
                    title=f"{book.title}: {duration_days}-Day Habit Roadmap",
                    duration_days=duration_days,
                    is_active=True,
                )

            item_instances = []
            for item in items_data:
                item_instances.append(
                    ActionPlanItem(
                        plan=plan,
                        day_number=item.get('day_number', len(item_instances) + 1),
                        title=item.get('title', f"Day {len(item_instances) + 1}"),
                        description=item.get('description', ''),
                        suggested_habit=item.get('suggested_habit', ''),
                        associated_quote=item.get('associated_quote', ''),
                        is_completed=False,
                    )
                )
            ActionPlanItem.objects.bulk_create(item_instances)

        return plan


class ActionPlanExportService:
    @staticmethod
    def to_markdown(plan: ActionPlan) -> str:
        """
        Exports the action plan as clean Markdown checklist.
        """
        lines = [
            f"# ⚡ {plan.book.title} — {plan.duration_days}-Day Habit Roadmap",
            f"**Author:** {plan.book.author.name}",
            f"**Status:** {plan.completed_items_count}/{plan.total_items_count} Days Completed ({plan.progress_percent}%)",
            "",
            "---",
            "",
        ]

        for item in plan.items.all().order_by('day_number'):
            check = "[x]" if item.is_completed else "[ ]"
            lines.append(f"### Day {item.day_number}: {item.title}")
            lines.append(f"- {check} **Daily Habit:** {item.suggested_habit}")
            lines.append(f"- **Implementation:** {item.description}")
            if item.associated_quote:
                lines.append(f"> {item.associated_quote}")
            lines.append("")

        return "\n".join(lines)

    @staticmethod
    def to_notion(plan: ActionPlan) -> str:
        """
        Exports formatted text optimized for direct paste into Notion.
        """
        lines = [
            f"# {plan.title}",
            f"> Grounded in *{plan.book.title}* by {plan.book.author.name}",
            f"> Progress: {plan.progress_percent}% completed",
            "",
        ]
        for item in plan.items.all().order_by('day_number'):
            check = "[x]" if item.is_completed else "[ ]"
            lines.append(f"## Day {item.day_number}: {item.title}")
            lines.append(f"{check} **Habit Formula:** {item.suggested_habit}")
            lines.append(f"{item.description}")
            if item.associated_quote:
                lines.append(f"> 💡 {item.associated_quote}")
            lines.append("")
        return "\n".join(lines)

    @staticmethod
    def to_ics(plan: ActionPlan, start_date: Optional[datetime] = None) -> str:
        """
        Exports the plan as RFC 5545 iCalendar (.ics) string with daily recurring events.
        """
        if start_date is None:
            start_date = timezone.now()

        cal_lines = [
            "BEGIN:VCALENDAR",
            "VERSION:2.0",
            "PRODID:-//Blinkist//Habit Roadmap 1.0//EN",
            "CALSCALE:GREGORIAN",
            "METHOD:PUBLISH",
            f"X-WR-CALNAME:{plan.title}",
        ]

        for item in plan.items.all().order_by('day_number'):
            event_date = start_date + timedelta(days=item.day_number - 1)
            # Schedule for 08:30 morning check-in
            dt_start = event_date.strftime("%Y%m%dT083000Z")
            dt_end = event_date.strftime("%Y%m%dT084500Z")
            stamp = timezone.now().strftime("%Y%m%dT%H%M%SZ")
            uid = f"blinkist-plan-{plan.id}-day-{item.day_number}@blinkist.com"

            description_clean = f"Daily Habit: {item.suggested_habit}\\n\\nAction: {item.description}"
            if item.associated_quote:
                description_clean += f"\\n\\nQuote: {item.associated_quote}"
            description_clean = description_clean.replace("\r", "").replace("\n", "\\n")

            cal_lines.extend([
                "BEGIN:VEVENT",
                f"UID:{uid}",
                f"DTSTAMP:{stamp}",
                f"DTSTART:{dt_start}",
                f"DTEND:{dt_end}",
                f"SUMMARY:Day {item.day_number}: {item.title}",
                f"DESCRIPTION:{description_clean}",
                f"STATUS:{'COMPLETED' if item.is_completed else 'CONFIRMED'}",
                "END:VEVENT",
            ])

        cal_lines.append("END:VCALENDAR")
        return "\r\n".join(cal_lines)
