from django.urls import path
from .views import DailyAudioDigestView, DailyAudioDigestProgressView

urlpatterns = [
    path('daily-digest/', DailyAudioDigestView.as_view(), name='daily-audio-digest'),
    path('daily-digest/progress/', DailyAudioDigestProgressView.as_view(), name='daily-audio-digest-progress'),
]
