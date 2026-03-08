# Blinkist Clone (Flutter & Django)

A comprehensive clone of the popular Blinkist app, built with a modern tech stack featuring a **Flutter** frontend for cross-platform mobile apps and a **Django** REST Framework backend for robust data management and APIs.

## 🚀 Features

*   **User Authentication:** Secure sign-up, login, and JWT-based session management.
*   **Book Summaries (Blinks):** Browse and read/listen to key insights from non-fiction books.
*   **Audio Playback:** Built-in audio player for listening to summaries on the go.
*   **Categories & Discovery:** Explore books by categories, curated lists, and personalized recommendations.
*   **Library & Progress Tracking:** Save books to your library, track reading/listening progress, and resume where you left off.
*   **Subscriptions:** Premium access management.
*   **Responsive UI:** Beautiful, smooth, and native-feeling user interface built with Flutter.

## 📸 Screenshots

| Home Screen | Summary View | Audio Player | Library |
| :---: | :---: | :---: | :---: |
| <img src="screenshots/home.png" width="200" alt="Home Screen Placeholder"/> | <img src="screenshots/summary.png" width="200" alt="Summary View Placeholder"/> | <img src="screenshots/player.png" width="200" alt="Audio Player Placeholder"/> | <img src="screenshots/library.png" width="200" alt="Library Placeholder"/> |

*(Note: Create a `screenshots/` directory in the root and add your actual app screenshots named `home.png`, `summary.png`, `player.png`, and `library.png` to replace the placeholders)*

## 🛠 Tech Stack

### Frontend (Mobile App)
*   **Framework:** [Flutter](https://flutter.dev/) (Dart)
*   **State Management:** Riverpod
*   **Networking:** Dio
*   **Local Storage:** Flutter Secure Storage

### Backend (API)
*   **Framework:** [Django](https://www.djangoproject.com/) & [Django REST Framework](https://www.django-rest-framework.org/) (Python)
*   **Database:** SQLite (Default for development)
*   **Authentication:** JWT (JSON Web Tokens)
*   **Task Queue:** Celery (for background tasks)

## 🏗 Project Structure

The project is divided into two main components:

*   **`/backend`**: The Django REST API project.
*   **`/mobile`**: The Flutter mobile application.

## 🏃‍♂️ Getting Started

### Prerequisites

*   [Python 3.10+](https://www.python.org/downloads/)
*   [Flutter SDK](https://docs.flutter.dev/get-started/install)
*   Git

### 1. Backend Setup

1.  Navigate to the backend directory:
    ```bash
    cd backend
    ```
2.  Create and activate a virtual environment (optional but recommended):
    ```bash
    python -m venv .venv
    source .venv/bin/activate  # On Windows use `.venv\Scripts\activate`
    ```
3.  Install dependencies:
    ```bash
    pip install -r requirements.txt
    ```
4.  Run database migrations:
    ```bash
    python manage.py migrate
    ```
5.  Start the development server:
    ```bash
    # We use port 8001 by default to avoid conflicts if 8000 is in use
    python manage.py runserver 8001
    ```

### 2. Frontend Setup

1.  Open a new terminal window and navigate to the mobile directory:
    ```bash
    cd mobile
    ```
2.  Get Flutter packages:
    ```bash
    flutter pub get
    ```
3.  Ensure your backend is running.
4.  Run the app on an emulator or connected device:
    ```bash
    flutter run
    ```
    *(Note: The app is configured to connect to `http://localhost:8001/api/v1` for iOS simulators and `http://10.0.2.2:8001/api/v1` for Android emulators. See `mobile/lib/core/networking/api_client.dart` for details).*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License.
