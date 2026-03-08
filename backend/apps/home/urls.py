from django.urls import path
from .views import HomeMerchandisingView

urlpatterns = [
    path('', HomeMerchandisingView.as_view(), name='home_merchandising'),
]
