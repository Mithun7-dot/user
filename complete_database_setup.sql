-- Complete database setup for Mithun Rocks app
-- Run this SQL in your Supabase SQL Editor

-- 1. Create addresses table
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

ALTER TABLE public.addresses
    ADD COLUMN IF NOT EXISTS line_2 TEXT,
    ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW();

ALTER TABLE public.addresses
    ALTER COLUMN pincode TYPE TEXT USING pincode::text,
    ALTER COLUMN phone TYPE TEXT USING phone::text,
    ALTER COLUMN city TYPE TEXT USING city::text,
    ALTER COLUMN state TYPE TEXT USING state::text,
    ALTER COLUMN full_name TYPE TEXT USING full_name::text,
    ALTER COLUMN line_1 TYPE TEXT USING line_1::text;

-- 2. Create cart table
CREATE TABLE IF NOT EXISTS public.cart (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    quantity INTEGER NOT NULL DEFAULT 1 CHECK (quantity > 0),
    size TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, product_id, size)
);

-- 3. Create users table (for admin panel)
CREATE TABLE IF NOT EXISTS public.users (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT NOT NULL UNIQUE,
    full_name TEXT,
    role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer', 'admin', 'ceo', 'stock_manager', 'pricing_manager', 'order_manager', 'qa_manager')),
    is_primary_admin BOOLEAN DEFAULT FALSE,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create coupons table
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code TEXT NOT NULL UNIQUE,
    discount_type TEXT NOT NULL CHECK (discount_type IN ('percentage', 'fixed')),
    discount_value DECIMAL(10,2) NOT NULL CHECK (discount_value > 0),
    min_order_amount DECIMAL(10,2) DEFAULT 0,
    max_discount DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 4. Create orders table
CREATE TABLE IF NOT EXISTS public.orders (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    address_id UUID REFERENCES public.addresses(id),
    total_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0,
    shipping_fee DECIMAL(10,2) DEFAULT 0,
    final_amount DECIMAL(10,2) NOT NULL,
    payment_method TEXT NOT NULL,
    payment_status TEXT NOT NULL DEFAULT 'pending',
    order_status TEXT NOT NULL DEFAULT 'pending',
    razorpay_order_id TEXT,
    razorpay_payment_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- 5. Create order_items table
CREATE TABLE IF NOT EXISTS public.order_items (
    id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    order_id UUID NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
    product_id UUID NOT NULL,
    product_name TEXT NOT NULL,
    product_price DECIMAL(10,2) NOT NULL,
    quantity INTEGER NOT NULL,
    size TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Create indexes for better performance
CREATE INDEX IF NOT EXISTS idx_addresses_user_id ON public.addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_addresses_is_default ON public.addresses(is_default) WHERE is_default = true;
CREATE INDEX IF NOT EXISTS idx_cart_user_id ON public.cart(user_id);
CREATE INDEX IF NOT EXISTS idx_users_email ON public.users(email);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON public.coupons(code);
CREATE INDEX IF NOT EXISTS idx_orders_user_id ON public.orders(user_id);
CREATE INDEX IF NOT EXISTS idx_order_items_order_id ON public.order_items(order_id);

-- Enable Row Level Security (RLS) on all tables
ALTER TABLE public.addresses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.cart ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;

-- Create RLS policies for addresses
DROP POLICY IF EXISTS "Users can view their own addresses" ON public.addresses;
CREATE POLICY "Users can view their own addresses" ON public.addresses
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert their own addresses" ON public.addresses;
CREATE POLICY "Users can insert their own addresses" ON public.addresses
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update their own addresses" ON public.addresses;
CREATE POLICY "Users can update their own addresses" ON public.addresses
    FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete their own addresses" ON public.addresses;
CREATE POLICY "Users can delete their own addresses" ON public.addresses
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for cart
DROP POLICY IF EXISTS "Users can view their own cart" ON public.cart;
CREATE POLICY "Users can view their own cart" ON public.cart
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert into their own cart" ON public.cart;
CREATE POLICY "Users can insert into their own cart" ON public.cart
    FOR INSERT WITH CHECK (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can update their own cart" ON public.cart;
CREATE POLICY "Users can update their own cart" ON public.cart
    FOR UPDATE USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can delete from their own cart" ON public.cart;
CREATE POLICY "Users can delete from their own cart" ON public.cart
    FOR DELETE USING (auth.uid() = user_id);

-- Create RLS policies for users (admin management)
CREATE OR REPLACE FUNCTION public.is_admin_user()
RETURNS boolean
LANGUAGE sql
SECURITY DEFINER
SET row_security = off
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.users
        WHERE id = auth.uid()
          AND role IN ('admin', 'ceo', 'pricing_manager')
    );
$$;

DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
CREATE POLICY "Users can view their own profile" ON public.users
    FOR SELECT USING (auth.uid() = id OR is_admin_user());

DROP POLICY IF EXISTS "Admins can view all users" ON public.users;
CREATE POLICY "Admins can view all users" ON public.users
    FOR SELECT USING (is_admin_user());

DROP POLICY IF EXISTS "Admins can update users" ON public.users;
CREATE POLICY "Admins can update users" ON public.users
    FOR UPDATE USING (auth.uid() = id OR is_admin_user());

DROP POLICY IF EXISTS "Admins can delete users" ON public.users;
CREATE POLICY "Admins can delete users" ON public.users
    FOR DELETE USING (is_admin_user());

DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
CREATE POLICY "Users can insert their own profile" ON public.users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- Create RLS policies for coupons (public read for active coupons)
DROP POLICY IF EXISTS "Anyone can view active coupons" ON public.coupons;
CREATE POLICY "Anyone can view active coupons" ON public.coupons
    FOR SELECT USING (is_active = true);

-- Admin users can manage all coupons
DROP POLICY IF EXISTS "Admins can view all coupons" ON public.coupons;
CREATE POLICY "Admins can view all coupons" ON public.coupons
    FOR SELECT USING (is_admin_user());

DROP POLICY IF EXISTS "Admins can insert coupons" ON public.coupons;
CREATE POLICY "Admins can insert coupons" ON public.coupons
    FOR INSERT WITH CHECK (is_admin_user());

DROP POLICY IF EXISTS "Admins can update coupons" ON public.coupons;
CREATE POLICY "Admins can update coupons" ON public.coupons
    FOR UPDATE USING (is_admin_user());

DROP POLICY IF EXISTS "Admins can delete coupons" ON public.coupons;
CREATE POLICY "Admins can delete coupons" ON public.coupons
    FOR DELETE USING (is_admin_user());

-- Create RLS policies for orders
DROP POLICY IF EXISTS "Users can view their own orders" ON public.orders;
CREATE POLICY "Users can view their own orders" ON public.orders
    FOR SELECT USING (auth.uid() = user_id);
DROP POLICY IF EXISTS "Users can insert their own orders" ON public.orders;
CREATE POLICY "Users can insert their own orders" ON public.orders
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Create RLS policies for order_items
DROP POLICY IF EXISTS "Users can view their own order items" ON public.order_items;
CREATE POLICY "Users can view their own order items" ON public.order_items
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE orders.id = order_items.order_id
            AND orders.user_id = auth.uid()
        )
    );
DROP POLICY IF EXISTS "Users can insert their own order items" ON public.order_items;
CREATE POLICY "Users can insert their own order items" ON public.order_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.orders
            WHERE orders.id = order_items.order_id
            AND orders.user_id = auth.uid()
        )
    );

-- Create function to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers to automatically update updated_at
DROP TRIGGER IF EXISTS update_addresses_updated_at ON public.addresses;
CREATE TRIGGER update_addresses_updated_at
    BEFORE UPDATE ON public.addresses
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_cart_updated_at ON public.cart;
CREATE TRIGGER update_cart_updated_at
    BEFORE UPDATE ON public.cart
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_users_updated_at ON public.users;
CREATE TRIGGER update_users_updated_at
    BEFORE UPDATE ON public.users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_coupons_updated_at ON public.coupons;
CREATE TRIGGER update_coupons_updated_at
    BEFORE UPDATE ON public.coupons
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_orders_updated_at ON public.orders;
CREATE TRIGGER update_orders_updated_at
    BEFORE UPDATE ON public.orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Insert some sample coupons for testing
INSERT INTO public.coupons (code, discount_type, discount_value, min_order_amount, max_discount)
VALUES
    ('WELCOME10', 'percentage', 10, 500, 100),
    ('SAVE50', 'fixed', 50, 200, NULL),
    ('FLAT20', 'percentage', 20, 1000, 200)
ON CONFLICT (code) DO NOTHING;