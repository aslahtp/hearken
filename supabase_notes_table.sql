-- Create notes table in Supabase
CREATE TABLE IF NOT EXISTS public.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  transcript TEXT NOT NULL,
  notes TEXT NOT NULL,
  audio_url TEXT NOT NULL,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  actionable_items TEXT
);

-- Create RLS policies for the notes table
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to select only their own notes
CREATE POLICY select_own_notes ON public.notes
  FOR SELECT USING (auth.uid() = user_id);

-- Policy to allow users to insert their own notes
CREATE POLICY insert_own_notes ON public.notes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy to allow users to update only their own notes
CREATE POLICY update_own_notes ON public.notes
  FOR UPDATE USING (auth.uid() = user_id);

-- Policy to allow users to delete only their own notes
CREATE POLICY delete_own_notes ON public.notes
  FOR DELETE USING (auth.uid() = user_id);

-- Create index for faster queries
CREATE INDEX notes_user_id_idx ON public.notes (user_id);
CREATE INDEX notes_created_at_idx ON public.notes (created_at DESC);
