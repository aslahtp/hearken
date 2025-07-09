# <p align="center">Hearken: Audio to Structured Learning Material</p>

<p align="center">
  <a href="#"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
  <a href="#"><img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python"></a>
  <a href="#"><img src="https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi" alt="FastAPI"></a>
  <a href="#"><img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"></a>
  <a href="#"><img src="https://img.shields.io/badge/Google_Gemini-007AC1?style=for-the-badge&logo=google-gemini&logoColor=white" alt="Google Gemini"></a>
</p>

## Introduction

Hearken is a project designed to convert lecture audios into structured learning materials. It leverages speech recognition and AI to transcribe audio, then transforms the transcription into organized notes or other study aids. The primary users are students, educators, and anyone seeking to extract information efficiently from audio content.

## Table of Contents

1.  [Key Features](#key-features)
2.  [Installation Guide](#installation-guide)
3.  [Usage](#usage)
4.  [API Reference](#api-reference)
5.  [Environment Variables](#environment-variables)
6.  [Project Structure](#project-structure)
7.  [Technologies Used](#technologies-used)
8.  [License](#license)

## Key Features

*   **Audio Transcription:** Utilizes Whisper for accurate speech-to-text conversion from various audio formats or URLs.
*   **Structured Notes Generation:** Employs Google Gemini to transform transcriptions into structured notes.
*   **User Authentication:** Secure user authentication handled with Supabase.
*   **Note Storage:** Notes can be stored and retrieved using Supabase.
*   **Cross-Platform Mobile App:** Built with Flutter for iOS, Android, Web, MacOS, Linux and Windows.

## Installation Guide

Follow these steps to set up Hearken for local development:

1.  **Clone the repository:**

    ```bash
    git clone <repository_url>
    cd <repository_directory>
    ```

2.  **Set up the backend (FastAPI):**

    ```bash
    cd backend
    python3 -m venv venv
    source venv/bin/activate  # On Windows: venv\Scripts\activate
    pip install -r requirements.txt
    ```

3.  **Configure environment variables:**

    Create a `.env` file in the `backend` directory and populate it with the necessary credentials (see [Environment Variables](#environment-variables) section).

4.  **Run the FastAPI server:**

    ```bash
    uvicorn app:app --reload
    ```

5.  **Set up the frontend (Flutter):**

    ```bash
    cd ../
    flutter pub get
    ```
    Ensure flutter SDK is configured correctly and all the platform requirements are met

6.  **Configure Supabase:**

    Create a new Supabase project and set up the `notes` table using the provided `supabase_notes_table.sql` script. Update `lib/services/supabase_service.dart` with your Supabase URL and API key.

7.  **Run the Flutter application:**

    ```bash
    flutter run
    ```

## Usage

### Backend (FastAPI)

The backend provides an API endpoint for processing audio files:

*   **/process\_audio:** Accepts audio files (via upload or URL) and returns a JSON transcription.

### Frontend (Flutter)

The Flutter app provides a user interface to:

*   Record or upload audio files.
*   View, edit, and manage notes.
*   Authenticate using Supabase.

## API Reference

### `/process_audio`

*   **Method:** `POST`
*   **Content-Type:** `multipart/form-data` (for file uploads) or `application/json` (for URL)
*   **Request Body (File Upload):**

    ```json
    {
        "audio_file": "<audio_file>"
    }
    ```

*   **Request Body (URL):**

    ```json
    {
        "audio_url": "<audio_url>"
    }
    ```

*   **Response:**

    ```json
    {
        "transcription": "<audio_transcription>"
    }
    ```

## Environment Variables

The following environment variables are required for the backend:

*   `GEMINI_API_KEY`: API key for Google Gemini.
*   `SUPABASE_URL`: The URL of your Supabase project.
*   `SUPABASE_ANON_KEY`: Your Supabase anon key.

## Project Structure

```
Hearken/
├── android/        # Android-specific files
├── ios/            # iOS-specific files
├── lib/            # Flutter source code
│   ├── main.dart                 # Entry point of the Flutter app
│   ├── screens/               # Flutter UI screens
│   │   ├── auth/                  # Authentication screens
│   │   │   ├── login_screen.dart   # Login screen
│   │   │   └── signup_screen.dart  # Signup screen
│   │   ├── home_screen.dart        # Home screen
│   │   ├── navigation_screen.dart  # Main navigation screen
│   │   ├── notes_screen.dart       # Screen for displaying notes
│   │   └── profile_screen.dart     # Screen for user profile
│   ├── services/              # Services
│   │   ├── gemini_service.dart   # Google Gemini service
│   │   └── supabase_service.dart # Supabase service
├── linux/          # Linux-specific files
├── macos/          # macOS-specific files
├── web/            # Web-specific files
├── windows/        # Windows-specific files
├── backend/        # FastAPI backend
│   ├── app.py               # Main FastAPI application
│   ├── requirements.txt   # Python dependencies
│   └── .env               # Environment variables (do not commit)
├── pubspec.yaml    # Flutter dependencies
├── supabase_notes_table.sql # SQL script for creating the notes table in Supabase
└── README.md
```

## Technologies Used

<p align="left">
    <a href="#"><img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"></a>
    <a href="#"><img src="https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white" alt="Python"></a>
    <a href="#"><img src="https://img.shields.io/badge/FastAPI-005571?style=for-the-badge&logo=fastapi" alt="FastAPI"></a>
    <a href="#"><img src="https://img.shields.io/badge/Supabase-3ECF8E?style=for-the-badge&logo=supabase&logoColor=white" alt="Supabase"></a>
    <a href="#"><img src="https://img.shields.io/badge/Google_Gemini-007AC1?style=for-the-badge&logo=google-gemini&logoColor=white" alt="Google Gemini"></a>
    <a href="#"><img src="https://img.shields.io/badge/Whisper-2E2E2E?style=for-the-badge&logo=openai&logoColor=white" alt="Whisper"></a>
</p>

*   **Frontend:** Flutter (Cross-platform mobile app)
*   **Backend:** FastAPI (Python)
*   **Database:** Supabase (PostgreSQL)
*   **AI Model:** Google Gemini
*   **Speech Recognition:** Whisper
*   **Authentication:** Supabase Auth

## License

MIT License

<p align="left">
    <a href="https://opensource.org/licenses/MIT"><img src="https://img.shields.io/badge/License-MIT-yellow.svg" alt="MIT License"></a>
</p>
