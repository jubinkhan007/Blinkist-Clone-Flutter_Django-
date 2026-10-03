from django.urls import path
from apps.summaries.audio_bookmark_views import (
    UserAudioBookmarkListCreateView,
    UserAudioBookmarkDetailView,
)

urlpatterns = [
    path('', UserAudioBookmarkListCreateView.as_view(), name='audio_bookmark_list_create'),
    path('<int:pk>/', UserAudioBookmarkDetailView.as_view(), name='audio_bookmark_detail'),
]
