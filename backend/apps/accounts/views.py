from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import get_user_model
from rest_framework_simplejwt.views import TokenObtainPairView
from .serializers import (
    RegisterSerializer,
    UserProfileUpdateSerializer,
    UserSerializer,
    OnboardingSubmissionSerializer,
)

User = get_user_model()

class RegisterView(generics.CreateAPIView):
    queryset = User.objects.all()
    permission_classes = (permissions.AllowAny,)
    serializer_class = RegisterSerializer

class UserProfileView(generics.RetrieveUpdateAPIView):
    permission_classes = (permissions.IsAuthenticated,)

    def get_serializer_class(self):
        if self.request.method in ('PATCH', 'PUT'):
            return UserProfileUpdateSerializer
        return UserSerializer

    def get_object(self):
        return self.request.user

    def update(self, request, *args, **kwargs):
        partial = kwargs.pop('partial', request.method == 'PATCH')
        serializer = self.get_serializer(
            self.get_object(),
            data=request.data,
            partial=partial,
        )
        serializer.is_valid(raise_exception=True)
        serializer.save()
        return Response(UserSerializer(self.get_object()).data)


ONBOARDING_TOPICS = [
    {
        'id': 'productivity',
        'slug': 'personal-development',
        'title': 'Productivity & Focus',
        'subtitle': 'Build high-performance habits and master your time',
        'icon': 'bolt',
    },
    {
        'id': 'entrepreneurship',
        'slug': 'business',
        'title': 'Entrepreneurship & Startups',
        'subtitle': 'Scaling companies, leadership, and bold ideas',
        'icon': 'rocket_launch',
    },
    {
        'id': 'psychology',
        'slug': 'psychology',
        'title': 'Psychology & Behavior',
        'subtitle': 'Understand cognitive biases, emotion, and decisions',
        'icon': 'psychology',
    },
    {
        'id': 'science',
        'slug': 'science',
        'title': 'Science & Technology',
        'subtitle': 'AI, physics, biology, and the frontier of the future',
        'icon': 'biotech',
    },
    {
        'id': 'leadership',
        'slug': 'business',
        'title': 'Management & Leadership',
        'subtitle': 'Inspire high-trust teams and execute strategy',
        'icon': 'groups',
    },
    {
        'id': 'mindfulness',
        'slug': 'self-help',
        'title': 'Mindfulness & Well-being',
        'subtitle': 'Stress resilience, mental clarity, and happiness',
        'icon': 'self_improvement',
    },
    {
        'id': 'history',
        'slug': 'history',
        'title': 'History & Society',
        'subtitle': 'Timeless lessons from world-shaping events and thinkers',
        'icon': 'history_edu',
    },
    {
        'id': 'personal_growth',
        'slug': 'personal-development',
        'title': 'Personal Growth',
        'subtitle': 'Communication, creativity, and lifelong learning',
        'icon': 'trending_up',
    },
]


class OnboardingTopicsView(APIView):
    permission_classes = (permissions.AllowAny,)

    def get(self, request, *args, **kwargs):
        return Response({'topics': ONBOARDING_TOPICS})


class OnboardingSubmitView(APIView):
    permission_classes = (permissions.IsAuthenticated,)

    def post(self, request, *args, **kwargs):
        serializer = OnboardingSubmissionSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        user = serializer.save(user=request.user)
        return Response(UserSerializer(user).data, status=status.HTTP_200_OK)

