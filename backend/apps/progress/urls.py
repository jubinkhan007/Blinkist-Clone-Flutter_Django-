from django.urls import path
from .views import (
    ReadProgressView,
    MarkSectionReadView,
    AudioProgressView,
    FullBookProgressView,
    UserReadingStatsView,
    RecordActivityView,
    UserBadgesView,
    ActionPlanGenerateView,
    ActionPlanListView,
    ActionPlanDetailView,
    ActionPlanItemToggleView,
    ActionPlanExportView,
    BulkProgressSyncView,
    ActivePlaybackSessionView,
    PlaybackHandoffView,
)

urlpatterns = [
    path('active-session/', ActivePlaybackSessionView.as_view(), name='active_playback_session'),
    path('active-session/handoff/', PlaybackHandoffView.as_view(), name='playback_handoff'),
    path('sync/', BulkProgressSyncView.as_view(), name='progress_sync'),
    path('stats/', UserReadingStatsView.as_view(), name='reading_stats'),
    path('badges/', UserBadgesView.as_view(), name='user_badges'),
    path('activity/', RecordActivityView.as_view(), name='record_activity'),
    path('action-plans/', ActionPlanListView.as_view(), name='action_plan_list'),
    path('action-plans/<int:pk>/', ActionPlanDetailView.as_view(), name='action_plan_detail'),
    path('action-plans/<int:pk>/items/<int:item_id>/toggle/', ActionPlanItemToggleView.as_view(), name='action_plan_item_toggle'),
    path('action-plans/<int:pk>/export/', ActionPlanExportView.as_view(), name='action_plan_export'),
    path('books/<str:book_identifier>/action-plan/generate/', ActionPlanGenerateView.as_view(), name='action_plan_generate'),
    path('books/<int:book_id>/', ReadProgressView.as_view(), name='book_progress'),
    path('books/<int:book_id>/section/<int:section_id>/', MarkSectionReadView.as_view(), name='mark_section_read'),
    path('books/<int:book_id>/audio/', AudioProgressView.as_view(), name='audio_progress'),
    path('books/<int:book_id>/full/', FullBookProgressView.as_view(), name='full_book_progress'),
]

