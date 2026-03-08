from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, UserProfileView

urlpatterns = [
    path('auth/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('auth/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
    path('auth/signup/', RegisterView.as_view(), name='auth_register'),
    path('me/', UserProfileView.as_view(), name='user_profile'),
]
