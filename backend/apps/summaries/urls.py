from django.urls import path

from .views import SummarySectionDetailView, SummarySectionListView

urlpatterns = [
    path('<slug:book_slug>/', SummarySectionListView.as_view(), name='summary_section_list'),
    path('<slug:book_slug>/<slug:slug>/', SummarySectionDetailView.as_view(), name='summary_section_detail'),
]
