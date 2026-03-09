from rest_framework import serializers
from django.contrib.auth import get_user_model
from django.utils import timezone

User = get_user_model()

class UserSerializer(serializers.ModelSerializer):
    is_premium = serializers.SerializerMethodField()
    trial_days_remaining = serializers.SerializerMethodField()

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
        )
        read_only_fields = (
            'id',
            'is_premium',
            'trial_days_remaining',
            'subscription_status',
            'subscription_end_date',
        )

    def get_is_premium(self, obj):
        return obj.has_premium_access()

    def get_trial_days_remaining(self, obj):
        return obj.trial_days_remaining()

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
