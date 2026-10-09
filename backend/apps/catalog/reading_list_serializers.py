from rest_framework import serializers
from .models import Book, UserReadingList, UserReadingListItem
from .serializers import BookListSerializer


class UserReadingListItemSerializer(serializers.ModelSerializer):
    book = BookListSerializer(read_only=True)

    class Meta:
        model = UserReadingListItem
        fields = ('id', 'book', 'order', 'note', 'added_at')


class UserReadingListSummarySerializer(serializers.ModelSerializer):
    owner_id = serializers.IntegerField(source='user.id', read_only=True)
    owner_name = serializers.SerializerMethodField()
    is_owner = serializers.SerializerMethodField()
    items_count = serializers.IntegerField(read_only=True)
    total_estimated_minutes = serializers.IntegerField(read_only=True)
    preview_covers = serializers.SerializerMethodField()

    class Meta:
        model = UserReadingList
        fields = (
            'id',
            'title',
            'description',
            'emoji',
            'color_hex',
            'is_public',
            'share_token',
            'owner_id',
            'owner_name',
            'is_owner',
            'items_count',
            'total_estimated_minutes',
            'preview_covers',
            'created_at',
            'updated_at',
        )

    def get_owner_name(self, obj):
        name = obj.user.get_full_name()
        if not name:
            name = obj.user.username or obj.user.email.split('@')[0]
        return name

    def get_is_owner(self, obj):
        request = self.context.get('request')
        if not request or not request.user or not request.user.is_authenticated:
            return False
        return obj.user_id == request.user.id

    def get_preview_covers(self, obj):
        request = self.context.get('request')
        covers = []
        # Use items with prefetched books
        for item in obj.items.select_related('book').all()[:4]:
            if item.book.cover_image:
                if request:
                    covers.append(request.build_absolute_uri(item.book.cover_image.url))
                else:
                    covers.append(item.book.cover_image.url)
        return covers


class UserReadingListDetailSerializer(UserReadingListSummarySerializer):
    items = UserReadingListItemSerializer(many=True, read_only=True)

    class Meta(UserReadingListSummarySerializer.Meta):
        fields = UserReadingListSummarySerializer.Meta.fields + ('items',)


class UserReadingListCreateUpdateSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserReadingList
        fields = ('title', 'description', 'emoji', 'color_hex', 'is_public')

    def validate_title(self, value):
        cleaned = value.strip()
        if not cleaned:
            raise serializers.ValidationError("Title cannot be blank.")
        return cleaned

    def validate_color_hex(self, value):
        cleaned = value.strip()
        if cleaned and not cleaned.startswith('#'):
            cleaned = f"#{cleaned}"
        return cleaned or '#3B82F6'


class AddBookToReadingListSerializer(serializers.Serializer):
    book_slug = serializers.CharField(required=True)
    note = serializers.CharField(required=False, allow_blank=True, default='')


class ReorderReadingListSerializer(serializers.Serializer):
    book_slugs = serializers.ListField(
        child=serializers.CharField(),
        allow_empty=False,
    )
