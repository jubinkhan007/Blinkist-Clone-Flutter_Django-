import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_repository.dart';
import '../../../../core/networking/api_client.dart';

class AuthState {
  final bool isLoading;
  final bool isLoggedIn;
  final AuthUser? user;

  AuthState({required this.isLoading, this.isLoggedIn = false, this.user});

  factory AuthState.initial() => AuthState(isLoading: true);

  AuthState copyWith({bool? isLoading, bool? isLoggedIn, AuthUser? user}) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isLoggedIn: isLoggedIn ?? this.isLoggedIn,
      user: user ?? this.user,
    );
  }
}

class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;

  AuthNotifier(this._repository) : super(AuthState.initial()) {
    _initialize();
  }

  Future<void> _initialize() async {
    state = state.copyWith(isLoading: true);
    final loggedIn = await _repository.isLoggedIn();
    if (!loggedIn) {
      state = state.copyWith(isLoading: false, isLoggedIn: false, user: null);
      return;
    }
    // Tokens exist — treat as logged in immediately so the app loads.
    // Fetch the profile in the background; the Dio interceptor will handle
    // token refresh or fire forceLogoutProvider if refresh also fails.
    state = state.copyWith(isLoading: false, isLoggedIn: true);
    final user = await _repository.getUserProfile();
    if (user != null) {
      state = state.copyWith(user: user);
    }
  }

  Future<void> login(String email, String password) async {
    state = state.copyWith(isLoading: true);
    await _repository.login(email: email, password: password);
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    final user = await _repository.getUserProfile();
    state = state.copyWith(
      isLoading: false,
      isLoggedIn: user != null,
      user: user,
    );
  }

  Future<void> logout() async {
    await _repository.logout();
    state = state.copyWith(isLoading: false, isLoggedIn: false, user: null);
  }
}

final authNotifierProvider = StateNotifierProvider<AuthNotifier, AuthState>((
  ref,
) {
  final repository = ref.watch(authRepositoryProvider);
  final notifier = AuthNotifier(repository);

  // Force logout when the interceptor clears tokens (e.g. refresh expired).
  // Also invalidate authStatusProvider so any UI watching it (e.g. ProfileScreen)
  // immediately reflects the logged-out state.
  ref.listen(forceLogoutProvider, (_, __) {
    notifier.logout();
    ref.invalidate(authStatusProvider);
  });

  return notifier;
});
