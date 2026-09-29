from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    is_premium = serializers.SerializerMethodField()
    trial_days_remaining = serializers.SerializerMethodField()
    current_streak = serializers.SerializerMethodField()
    longest_streak = serializers.IntegerField(read_only=True)
    last_active_date = serializers.DateField(read_only=True)

    class Meta:
        model = User
        fields = (
            'id',
            'email',
            'username',
            'first_name',
            'last_name',
            'is_premium',
            'trial_days_remaining',
            'subscription_status',
            'subscription_end_date',
            'bio',
            'avatar_url',
            'current_streak',
            'longest_streak',
            'last_active_date',
            'has_completed_onboarding',
            'reading_goal',
            'preferred_format',
            'interest_topics',
        )
        read_only_fields = (
            'id',
            'is_premium',
            'trial_days_remaining',
            'subscription_status',
            'subscription_end_date',
            'current_streak',
            'longest_streak',
            'last_active_date',
        )

    def get_is_premium(self, obj):
        return obj.has_premium_access()

    def get_trial_days_remaining(self, obj):
        return obj.trial_days_remaining()

    def get_current_streak(self, obj):
        return obj.get_current_streak()

class RegisterSerializer(serializers.ModelSerializer):
    password = serializers.CharField(write_only=True)
    display_name = serializers.CharField(write_only=True, required=False)

    class Meta:
        model = User
        fields = (
            'email',
            'username',
            'display_name',
            'password',
            'first_name',
            'last_name',
        )
        extra_kwargs = {'username': {'required': False}}

    def validate(self, attrs):
        if not attrs.get('username'):
            attrs['username'] = (
                attrs.get('display_name')
                or attrs.get('email', '').split('@')[0]
                or 'user'
            )
        return attrs

    def create(self, validated_data):
        validated_data.pop('display_name', None)
        user = User.objects.create_user(
            email=validated_data['email'],
            username=validated_data['username'],
            password=validated_data['password'],
            first_name=validated_data.get('first_name', ''),
            last_name=validated_data.get('last_name', '')
        )
        if user.trial_started_at is None:
            user.trial_started_at = timezone.now()
            user.subscription_status = User.SubscriptionStatus.TRIALING
            user.save(update_fields=['trial_started_at', 'subscription_status'])
        return user


class UserProfileUpdateSerializer(serializers.ModelSerializer):
    interest_topics = serializers.ListField(
        child=serializers.CharField(),
        required=False,
    )

    class Meta:
        model = User
        fields = (
            'first_name',
            'last_name',
            'bio',
            'avatar_url',
            'reading_goal',
            'preferred_format',
            'interest_topics',
        )

    def validate_first_name(self, value):
        if not value.strip():
            raise serializers.ValidationError('First name is required.')
        return value.strip()

    def validate_last_name(self, value):
        if not value.strip():
            raise serializers.ValidationError('Last name is required.')
        return value.strip()


class OnboardingSubmissionSerializer(serializers.Serializer):
    reading_goal = serializers.CharField(max_length=50, required=False, allow_blank=True, default='')
    preferred_format = serializers.CharField(max_length=20, required=False, default='both')
    interest_topics = serializers.ListField(
        child=serializers.CharField(),
        required=False,
        default=list,
    )

    def save(self, user):
        from django.core.cache import cache
        from apps.catalog.models import Category

        reading_goal = self.validated_data.get('reading_goal', user.reading_goal)
        preferred_format = self.validated_data.get('preferred_format', user.preferred_format)
        interest_topics = self.validated_data.get('interest_topics', user.interest_topics)

        user.reading_goal = reading_goal
        user.preferred_format = preferred_format
        user.interest_topics = interest_topics
        user.has_completed_onboarding = True
        user.save(update_fields=[
            'reading_goal',
            'preferred_format',
            'interest_topics',
            'has_completed_onboarding',
        ])

        # Link matching categories
        if interest_topics:
            matched_categories = Category.objects.filter(slug__in=interest_topics)
            user.interest_categories.set(matched_categories)

        # Invalidate home feed cache
        cache.delete(f'home_feed_{user.id}')
        return user

