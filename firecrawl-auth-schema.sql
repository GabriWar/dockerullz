-- Firecrawl Authentication Schema
-- This SQL file creates all necessary tables and functions for Firecrawl authentication

-- Extensions
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- ============================================================================
-- TABLES
-- ============================================================================

-- Teams table
CREATE TABLE IF NOT EXISTS public.teams (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT,
    auto_recharge BOOLEAN DEFAULT false,
    auto_recharge_threshold INTEGER DEFAULT 1000,
    hmac_secret TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Customers table (for Stripe integration)
CREATE TABLE IF NOT EXISTS public.customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stripe_customer_id TEXT UNIQUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Products table (for pricing plans)
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    description TEXT,
    is_enterprise BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Prices table (for pricing tiers)
CREATE TABLE IF NOT EXISTS public.prices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id),
    active BOOLEAN DEFAULT true,
    currency TEXT DEFAULT 'usd',
    unit_amount INTEGER,
    metadata JSONB DEFAULT '{}'::jsonb,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Subscriptions table
CREATE TABLE IF NOT EXISTS public.subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID REFERENCES public.teams(id),
    user_id UUID REFERENCES public.customers(id),
    price_id UUID REFERENCES public.prices(id),
    status TEXT DEFAULT 'active',
    quantity INTEGER DEFAULT 1,
    cancel_at_period_end BOOLEAN DEFAULT false,
    cancel_at TIMESTAMP WITH TIME ZONE,
    canceled_at TIMESTAMP WITH TIME ZONE,
    current_period_start TIMESTAMP WITH TIME ZONE,
    current_period_end TIMESTAMP WITH TIME ZONE,
    created TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    ended_at TIMESTAMP WITH TIME ZONE,
    trial_start TIMESTAMP WITH TIME ZONE,
    trial_end TIMESTAMP WITH TIME ZONE,
    is_extract BOOLEAN DEFAULT false,
    metadata JSONB DEFAULT '{}'::jsonb
);

-- API Keys table
CREATE TABLE IF NOT EXISTS public.api_keys (
    id SERIAL PRIMARY KEY,
    key UUID NOT NULL UNIQUE DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Credit bills table (for tracking credit usage)
CREATE TABLE IF NOT EXISTS public.credit_bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(id),
    subscription_id UUID REFERENCES public.subscriptions(id),
    api_key_id INTEGER REFERENCES public.api_keys(id),
    credits INTEGER NOT NULL DEFAULT 0,
    is_extract BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    tallied BOOLEAN DEFAULT false
);

-- Coupons table (for credit discounts)
CREATE TABLE IF NOT EXISTS public.coupons (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    team_id UUID NOT NULL REFERENCES public.teams(id),
    credits INTEGER NOT NULL DEFAULT 0,
    used BOOLEAN DEFAULT false,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ============================================================================
-- INDEXES
-- ============================================================================

CREATE INDEX IF NOT EXISTS idx_api_keys_key ON public.api_keys(key);
CREATE INDEX IF NOT EXISTS idx_api_keys_team_id ON public.api_keys(team_id);
CREATE INDEX IF NOT EXISTS idx_credit_bills_team_id ON public.credit_bills(team_id);
CREATE INDEX IF NOT EXISTS idx_credit_bills_tallied ON public.credit_bills(tallied);
CREATE INDEX IF NOT EXISTS idx_subscriptions_team_id ON public.subscriptions(team_id);
CREATE INDEX IF NOT EXISTS idx_subscriptions_status ON public.subscriptions(status);

-- Firecrawl Jobs table (for tracking crawl/scrape/extract jobs)
CREATE TABLE IF NOT EXISTS public.firecrawl_jobs (
    job_id TEXT PRIMARY KEY,
    success BOOLEAN NOT NULL,
    message TEXT,
    num_docs INTEGER NOT NULL DEFAULT 0,
    docs JSONB,
    time_taken DOUBLE PRECISION NOT NULL,
    team_id TEXT,
    mode TEXT NOT NULL,
    url TEXT,
    crawler_options JSONB,
    page_options JSONB,
    origin TEXT,
    integration TEXT,
    num_tokens DOUBLE PRECISION,
    retry BOOLEAN DEFAULT false,
    crawl_id TEXT,
    tokens_billed INTEGER,
    is_migrated BOOLEAN DEFAULT true,
    cost_tracking JSONB,
    pdf_num_pages INTEGER,
    credits_billed INTEGER,
    change_tracking_tag TEXT,
    dr_clean_by TIMESTAMP WITH TIME ZONE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_firecrawl_jobs_team_id ON public.firecrawl_jobs(team_id);
CREATE INDEX IF NOT EXISTS idx_firecrawl_jobs_crawl_id ON public.firecrawl_jobs(crawl_id);
CREATE INDEX IF NOT EXISTS idx_firecrawl_jobs_created_at ON public.firecrawl_jobs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_firecrawl_jobs_mode ON public.firecrawl_jobs(mode);

-- ============================================================================
-- FUNCTIONS
-- ============================================================================

-- Function to get auth credit usage chunk for API key
CREATE OR REPLACE FUNCTION public.auth_credit_usage_chunk_35(
    input_key UUID,
    i_is_extract BOOLEAN,
    tally_untallied_credits BOOLEAN
)
RETURNS TABLE (
    api_key UUID,
    api_key_id INTEGER,
    team_id UUID,
    sub_id UUID,
    sub_current_period_start TIMESTAMP WITH TIME ZONE,
    sub_current_period_end TIMESTAMP WITH TIME ZONE,
    sub_user_id UUID,
    price_id UUID,
    price_credits INTEGER,
    price_should_be_graceful BOOLEAN,
    price_associated_auto_recharge_price_id UUID,
    credits_used INTEGER,
    coupon_credits INTEGER,
    adjusted_credits_used INTEGER,
    remaining_credits INTEGER,
    total_credits_sum INTEGER,
    plan_priority JSONB,
    rate_limits JSONB,
    concurrency INTEGER,
    flags JSONB
) AS $$
DECLARE
    v_team_id UUID;
    v_api_key_id INTEGER;
    v_subscription_id UUID;
    v_sub_user_id UUID;
    v_price_credits INTEGER := 500; -- default free credits
    v_credits_used INTEGER := 0;
    v_coupon_credits INTEGER := 0;
    v_rate_limits JSONB;
    v_flags JSONB;
BEGIN
    -- Get API key info
    SELECT a.id, a.team_id INTO v_api_key_id, v_team_id
    FROM public.api_keys a
    WHERE a.key = input_key
    LIMIT 1;
    
    -- If API key doesn't exist, return empty
    IF v_api_key_id IS NULL THEN
        RETURN;
    END IF;
    
    -- Get subscription info
    SELECT s.id, s.user_id INTO v_subscription_id, v_sub_user_id
    FROM public.subscriptions s
    WHERE s.team_id = v_team_id 
        AND s.status = 'active'
    LIMIT 1;
    
    -- Calculate credits used
    SELECT COALESCE(SUM(cb.credits), 0) INTO v_credits_used
    FROM public.credit_bills cb
    WHERE cb.team_id = v_team_id
        AND (i_is_extract = false OR cb.is_extract = true);
    
    -- Calculate coupon credits
    SELECT COALESCE(SUM(c.credits), 0) INTO v_coupon_credits
    FROM public.coupons c
    WHERE c.team_id = v_team_id AND c.used = false;
    
    -- Default rate limits for free tier
    v_rate_limits := jsonb_build_object(
        'crawl', 10,
        'scrape', 100,
        'search', 10,
        'map', 10,
        'extract', 10,
        'preview', 20,
        'crawlStatus', 100,
        'extractStatus', 100
    );
    
    v_flags := '{}'::jsonb;
    
    -- Return the chunk
    RETURN QUERY SELECT
        input_key as api_key,
        v_api_key_id as api_key_id,
        v_team_id as team_id,
        v_subscription_id as sub_id,
        NULL::TIMESTAMP WITH TIME ZONE as sub_current_period_start,
        NULL::TIMESTAMP WITH TIME ZONE as sub_current_period_end,
        NULL::UUID as sub_user_id,
        NULL::UUID as price_id,
        v_price_credits as price_credits,
        false as price_should_be_graceful,
        NULL::UUID as price_associated_auto_recharge_price_id,
        v_credits_used as credits_used,
        v_coupon_credits as coupon_credits,
        v_credits_used - v_coupon_credits as adjusted_credits_used,
        v_price_credits - (v_credits_used - v_coupon_credits) as remaining_credits,
        v_price_credits as total_credits_sum,
        jsonb_build_object('bucketLimit', 100, 'planModifier', 1) as plan_priority,
        v_rate_limits as rate_limits,
        10 as concurrency,
        v_flags as flags;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get auth credit usage chunk for team
CREATE OR REPLACE FUNCTION public.auth_credit_usage_chunk_35_from_team(
    input_team UUID,
    i_is_extract BOOLEAN,
    tally_untallied_credits BOOLEAN
)
RETURNS TABLE (
    api_key UUID,
    api_key_id INTEGER,
    team_id UUID,
    sub_id UUID,
    sub_current_period_start TIMESTAMP WITH TIME ZONE,
    sub_current_period_end TIMESTAMP WITH TIME ZONE,
    sub_user_id UUID,
    price_id UUID,
    price_credits INTEGER,
    price_should_be_graceful BOOLEAN,
    price_associated_auto_recharge_price_id UUID,
    credits_used INTEGER,
    coupon_credits INTEGER,
    adjusted_credits_used INTEGER,
    remaining_credits INTEGER,
    total_credits_sum INTEGER,
    plan_priority JSONB,
    rate_limits JSONB,
    concurrency INTEGER,
    flags JSONB
) AS $$
DECLARE
    v_subscription_id UUID;
    v_sub_user_id UUID;
    v_price_credits INTEGER := 500; -- default free credits
    v_credits_used INTEGER := 0;
    v_coupon_credits INTEGER := 0;
    v_rate_limits JSONB;
    v_flags JSONB;
BEGIN
    -- Get subscription info
    SELECT s.id, s.user_id INTO v_subscription_id, v_sub_user_id
    FROM public.subscriptions s
    WHERE s.team_id = input_team 
        AND s.status = 'active'
    LIMIT 1;
    
    -- Calculate credits used
    SELECT COALESCE(SUM(cb.credits), 0) INTO v_credits_used
    FROM public.credit_bills cb
    WHERE cb.team_id = input_team
        AND (i_is_extract = false OR cb.is_extract = true);
    
    -- Calculate coupon credits
    SELECT COALESCE(SUM(c.credits), 0) INTO v_coupon_credits
    FROM public.coupons c
    WHERE c.team_id = input_team AND c.used = false;
    
    -- Default rate limits for free tier
    v_rate_limits := jsonb_build_object(
        'crawl', 10,
        'scrape', 100,
        'search', 10,
        'map', 10,
        'extract', 10,
        'preview', 20,
        'crawlStatus', 100,
        'extractStatus', 100
    );
    
    v_flags := '{}'::jsonb;
    
    -- Return the chunk
    RETURN QUERY SELECT
        NULL::UUID as api_key,
        0 as api_key_id,
        input_team as team_id,
        v_subscription_id as sub_id,
        NULL::TIMESTAMP WITH TIME ZONE as sub_current_period_start,
        NULL::TIMESTAMP WITH TIME ZONE as sub_current_period_end,
        NULL::UUID as sub_user_id,
        NULL::UUID as price_id,
        v_price_credits as price_credits,
        false as price_should_be_graceful,
        NULL::UUID as price_associated_auto_recharge_price_id,
        v_credits_used as credits_used,
        v_coupon_credits as coupon_credits,
        v_credits_used - v_coupon_credits as adjusted_credits_used,
        v_price_credits - (v_credits_used - v_coupon_credits) as remaining_credits,
        v_price_credits as total_credits_sum,
        jsonb_build_object('bucketLimit', 100, 'planModifier', 1) as plan_priority,
        v_rate_limits as rate_limits,
        10 as concurrency,
        v_flags as flags;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================================
-- INSERT TEST DATA
-- ============================================================================

-- Insert test team
INSERT INTO public.teams (id, name) VALUES 
('00000000-0000-0000-0000-000000000001', 'Test Team')
ON CONFLICT (id) DO NOTHING;

-- Insert test API key
INSERT INTO public.api_keys (key, team_id) VALUES 
('12345678-1234-5678-90ab-123456789abc'::UUID, '00000000-0000-0000-0000-000000000001'::UUID)
ON CONFLICT (key) DO NOTHING;

-- ============================================================================
-- GRANT PERMISSIONS
-- ============================================================================

-- Grant SELECT on all tables to anon role (for public access via Supabase)
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO authenticated;

-- Grant EXECUTE on functions
GRANT EXECUTE ON FUNCTION public.auth_credit_usage_chunk_35 TO anon;
GRANT EXECUTE ON FUNCTION public.auth_credit_usage_chunk_35_from_team TO anon;

