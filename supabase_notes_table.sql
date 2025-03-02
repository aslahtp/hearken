-- SQL to create notes table in Supabase
CREATE TABLE IF NOT EXISTS public.notes (id SERIAL PRIMARY KEY, user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE, transcript TEXT NOT NULL, notes TEXT NOT NULL, audio_url TEXT NOT NULL, created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(), CONSTRAINT notes_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE);

-- Add RLS (Row Level Security) policies
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

-- Policy to allow users to select only their own notes
CREATE POLICY select_own_notes ON public.notes FOR SELECT USING (auth.uid() = user_id);

-- Policy to allow users to insert their own notes
CREATE POLICY insert_own_notes ON public.notes FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Policy to allow users to update their own notes
CREATE POLICY update_own_notes ON public.notes FOR UPDATE USING (auth.uid() = user_id);

-- Policy to allow users to delete their own notes
CREATE POLICY delete_own_notes ON public.notes FOR DELETE USING (auth.uid() = user_id);

-- Grant access to authenticated users
GRANT ALL ON public.notes TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.notes_id_seq TO authenticated;
-- Add RLS (Row Level Security) policies
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY select_own_notes ON public.notes FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY insert_own_notes ON public.notes FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY update_own_notes ON public.notes FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY delete_own_notes ON public.notes FOR DELETE USING (auth.uid() = user_id);
GRANT ALL ON public.notes TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.notes_id_seq TO authenticated;
