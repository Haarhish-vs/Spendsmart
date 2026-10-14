-- ==============================================================================
-- SpendSmart Database Migration: Custom Authentication with public.app_users
-- ==============================================================================
-- Purpose:
--   Migrate SpendSmart identity from Supabase Auth (auth.users) to custom authentication
--   using public.app_users with bcrypt password hashing and JWT sessions.
--
-- Instructions:
--   Run this script in the Supabase Dashboard SQL Editor (or psql console).
--   It is safe and idempotent. Existing records are preserved.
-- ==============================================================================

BEGIN;

-- 1. Ensure public.app_users exists with required schema
CREATE TABLE IF NOT EXISTS public.app_users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    full_name TEXT NOT NULL,
    email TEXT NOT NULL,
    password_hash TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT true,
    email_verified BOOLEAN NOT NULL DEFAULT false,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Case-insensitive unique index on email
CREATE UNIQUE INDEX IF NOT EXISTS app_users_email_lower_idx 
    ON public.app_users (LOWER(email));

-- 2. Ensure profiles table has onboarding columns
ALTER TABLE public.profiles 
    ADD COLUMN IF NOT EXISTS selected_bank TEXT,
    ADD COLUMN IF NOT EXISTS tracking_start TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS employment_status TEXT;

-- 3. Safely align foreign key constraints to reference public.app_users(id)

-- profiles -> app_users(id)
ALTER TABLE public.profiles 
    DROP CONSTRAINT IF EXISTS profiles_id_fkey;

ALTER TABLE public.profiles 
    ADD CONSTRAINT profiles_id_fkey 
    FOREIGN KEY (id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- transactions -> app_users(id)
ALTER TABLE public.transactions 
    DROP CONSTRAINT IF EXISTS transactions_user_id_fkey;

ALTER TABLE public.transactions 
    ADD CONSTRAINT transactions_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- budgets -> app_users(id)
ALTER TABLE public.budgets 
    DROP CONSTRAINT IF EXISTS budgets_user_id_fkey;

ALTER TABLE public.budgets 
    ADD CONSTRAINT budgets_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- device_tokens -> app_users(id)
ALTER TABLE public.device_tokens 
    DROP CONSTRAINT IF EXISTS device_tokens_user_id_fkey;

ALTER TABLE public.device_tokens 
    ADD CONSTRAINT device_tokens_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- notifications -> app_users(id)
ALTER TABLE public.notifications 
    DROP CONSTRAINT IF EXISTS notifications_user_id_fkey;

ALTER TABLE public.notifications 
    ADD CONSTRAINT notifications_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- budget_alerts -> app_users(id)
ALTER TABLE public.budget_alerts 
    DROP CONSTRAINT IF EXISTS budget_alerts_user_id_fkey;

ALTER TABLE public.budget_alerts 
    ADD CONSTRAINT budget_alerts_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- goals -> app_users(id)
ALTER TABLE public.goals 
    DROP CONSTRAINT IF EXISTS goals_user_id_fkey;

ALTER TABLE public.goals 
    ADD CONSTRAINT goals_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- financial_plans -> app_users(id)
ALTER TABLE public.financial_plans 
    DROP CONSTRAINT IF EXISTS financial_plans_user_id_fkey;

ALTER TABLE public.financial_plans 
    ADD CONSTRAINT financial_plans_user_id_fkey 
    FOREIGN KEY (user_id) REFERENCES public.app_users(id) 
    ON DELETE CASCADE;

-- 4. Enable Row Level Security (RLS) policies if needed
-- When accessing via Node.js backend with service role key, RLS is bypassed.
-- RLS can remain enabled to protect direct public API access.
ALTER TABLE public.app_users ENABLE ROW LEVEL SECURITY;

COMMIT;
