from __future__ import annotations

from typing import Any, Dict, Optional
from rest_framework import serializers

from apps.catalog.models import Book, Category, ContentIngestionJob
from apps.progress.models import ActionPlan
from apps.summaries.models import BookFlashcard


class IngestedBookSummarySerializer(serializers.ModelSerializer):
    author = serializers.CharField(source='author.name', read_only=True)
    category = serializers.SerializerMethodField()
    cover_image_url = serializers.SerializerMethodField()
    sections_count = serializers.SerializerMethodField()
    has_audio = serializers.SerializerMethodField()
    flashcards_count = serializers.SerializerMethodField()
    action_plan_id = serializers.SerializerMethodField()

    def get_category(self, obj: Book) -> str:
        first_cat = obj.categories.first()
        return first_cat.name if first_cat else ''

    class Meta:
        model = Book
        fields = (
            'id',
            'slug',
            'title',
            'subtitle',
            'author',
            'category',
            'cover_image_url',
            'estimated_read_time_minutes',
            'sections_count',
            'has_audio',
            'flashcards_count',
            'action_plan_id',
        )

    def get_cover_image_url(self, obj: Book) -> Optional[str]:
        if obj.cover_image:
            request = self.context.get('request')
            if request:
                return request.build_absolute_uri(obj.cover_image.url)
            return obj.cover_image.url
        return None

    def get_sections_count(self, obj: Book) -> int:
        return obj.sections.count()

    def get_has_audio(self, obj: Book) -> bool:
        return obj.sections.filter(audio_file__isnull=False).exclude(audio_file='').exists()

    def get_flashcards_count(self, obj: Book) -> int:
        return BookFlashcard.objects.filter(book=obj).count()

    def get_action_plan_id(self, obj: Book) -> Optional[int]:
        plan = ActionPlan.objects.filter(book=obj, is_active=True).first()
        return plan.id if plan else None


class ContentIngestionJobDetailSerializer(serializers.ModelSerializer):
    book = IngestedBookSummarySerializer(read_only=True)
    target_category_name = serializers.CharField(source='target_category.name', read_only=True, default='')
    created_by_email = serializers.CharField(source='created_by.email', read_only=True, default='')

    class Meta:
        model = ContentIngestionJob
        fields = (
            'id',
            'source_type',
            'input_query',
            'target_category',
            'target_category_name',
            'voice_name',
            'generate_audio',
            'generate_flashcards',
            'generate_action_plan',
            'status',
            'progress_percent',
            'current_step',
            'logs',
            'book',
            'created_by_email',
            'created_at',
            'updated_at',
        )


class ContentIngestionJobCreateSerializer(serializers.Serializer):
    file = serializers.FileField(required=False, allow_null=True)
    source_type = serializers.ChoiceField(
        choices=ContentIngestionJob.SOURCE_TYPE_CHOICES,
        default='PDF',
    )
    input_query = serializers.CharField(required=False, allow_blank=True, default='')
    target_category_id = serializers.IntegerField(required=False, allow_null=True)
    voice_name = serializers.CharField(required=False, default='en-US-ChristopherNeural')
    generate_audio = serializers.BooleanField(required=False, default=True)
    generate_flashcards = serializers.BooleanField(required=False, default=True)
    generate_action_plan = serializers.BooleanField(required=False, default=True)
    run_synchronously = serializers.BooleanField(required=False, default=False)

    def validate(self, attrs: Dict[str, Any]) -> Dict[str, Any]:
        source_type = attrs.get('source_type', 'PDF')
        file_obj = attrs.get('file')
        input_query = attrs.get('input_query', '').strip()

        if source_type in ('PDF', 'EPUB'):
            if not file_obj and not input_query:
                raise serializers.ValidationError(
                    f"A file (.pdf or .epub) is required when source_type is {source_type}."
                )
            if file_obj:
                filename = file_obj.name.lower()
                if source_type == 'PDF' and not filename.endswith('.pdf'):
                    raise serializers.ValidationError("File must be a valid PDF document (.pdf).")
                if source_type == 'EPUB' and not filename.endswith('.epub'):
                    raise serializers.ValidationError("File must be a valid EPUB e-book (.epub).")
        elif source_type == 'METADATA':
            if not input_query:
                raise serializers.ValidationError(
                    "input_query (title, author, ISBN, or topic) is required for METADATA ingestion."
                )

        target_category_id = attrs.get('target_category_id')
        if target_category_id:
            if not Category.objects.filter(id=target_category_id).exists():
                raise serializers.ValidationError(f"Category with id {target_category_id} does not exist.")

        return attrs
