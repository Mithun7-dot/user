-- Create addresses table for Mithun Rocks app
CREATE TABLE IF NOT EXISTS public.addresses (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    full_name TEXT NOT NULL,
    phone TEXT NOT NULL,
    line_1 TEXT NOT NULL,
    line_2 TEXT,
    city TEXT NOT NULL,
    state TEXT NOT NULL,
    pincode TEXT NOT NULL,
    is_default BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create index on user_id for faster queries
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON public.addresses(user_id);

-- Create index on is_default for faster default address queries
CREATE INDEX IF NOT EXISTS idx_addresses_is_default ON public.addresses(is_default) WHERE is_default = true;

-- Enable Row Level Security (RLS)
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;

-- Create policy to allow users to only access their own addresses
CREATE POLICY "Users can view their own addresses" ON public.addresses
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own addresses" ON public.addresses
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own addresses" ON public.addresses
    FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete their own addresses" ON public.addresses
    FOR DELETE USING (auth.uid() = user_id);

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create trigger to automatically update updated_at
CREATE TRIGGER update_addresses_updated_at
    BEFORE UPDATE ON public.addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();