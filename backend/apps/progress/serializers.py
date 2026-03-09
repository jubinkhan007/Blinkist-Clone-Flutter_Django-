from rest_framework import serializers
from .models import UserBookProgress, UserSectionProgress, UserAudioProgress

class UserBookProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserBookProgress
        fields = ('id', 'book', 'current_section', 'percent_complete', 'last_read_at', 'is_completed')
        read_only_fields = ('id', 'last_read_at')

class UserSectionProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserSectionProgress
        fields = ('id', 'section', 'is_completed', 'read_at')
        read_only_fields = ('id', 'read_at')

class UserAudioProgressSerializer(serializers.ModelSerializer):
    class Meta:
        model = UserAudioProgress
        fields = ('id', 'book', 'current_section', 'current_position_seconds', 'is_finished', 'last_listened_at')
        read_only_fields = ('id', 'last_listened_at')
