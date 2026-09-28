from django.urls import path
from apps.summaries.highlight_views import (
    UserHighlightListCreateView,
    UserHighlightDetailView,
)

urlpatterns = [
    path('', UserHighlightListCreateView.as_view(), name='user_highlight_list_create'),
    path('<int:pk>/', UserHighlightDetailView.as_view(), name='user_highlight_detail'),
]
