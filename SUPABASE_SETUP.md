# Supabase Setup for Hearken App

This document provides instructions on how to set up the Supabase database for the Hearken app.

## Prerequisites

- A Supabase account (sign up at [supabase.com](https://supabase.com))
- Access to your Supabase project dashboard

## Database Setup

1. Log in to your Supabase dashboard
2. Navigate to the SQL Editor
3. Create a new query
4. Copy and paste the contents of the `supabase_notes_table.sql` file into the SQL Editor
5. Run the query to create the necessary tables and policies

## SQL Commands

The SQL commands in `supabase_notes_table.sql` will:

1. Create a `notes` table with the following columns:
   - `id`: UUID primary key
   - `user_id`: UUID foreign key referencing the auth.users table
   - `title`: Text field for the note title
   - `transcript`: Text field for the audio transcript
   - `notes`: Text field for the processed notes
   - `audio_url`: Text field for the audio file URL
   - `created_at`: Timestamp for when the note was created
   - `updated_at`: Timestamp for when the note was last updated

2. Enable Row Level Security (RLS) on the `notes` table

3. Create RLS policies to ensure users can only:
   - Select their own notes
   - Insert their own notes
   - Update their own notes
   - Delete their own notes

4. Create indexes for faster queries

## Storage Setup

1. In your Supabase dashboard, navigate to Storage
2. Create a new bucket named `audio`
3. Set the bucket's privacy to "Authenticated"
4. Create a policy for the bucket to allow authenticated users to:
   - Upload files
   - Download files
   - Delete their own files

## Environment Variables

Make sure your app has the correct Supabase URL and anon key in the `lib/services/supabase_service.dart` file:

```dart
static const String supabaseUrl = 'YOUR_SUPABASE_URL';
static const String supabaseAnonKey = 'YOUR_SUPABASE_ANON_KEY';
```

## Testing

After setting up the database:

1. Run the app
2. Sign up or sign in
3. Upload an audio file
4. Process the audio
5. Check the Notes screen to see if the notes are saved and displayed correctly

## Troubleshooting

If you encounter issues:

1. Check the Supabase dashboard logs for any errors
2. Verify that the RLS policies are correctly set up
3. Ensure the storage bucket is properly configured
4. Check that your app has the correct Supabase URL and anon key 