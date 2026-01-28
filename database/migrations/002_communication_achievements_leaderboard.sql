-- Migration: Communication, Achievements, and Leaderboard System
-- Version: 002
-- Description: Creates tables for chat messages, user presence, achievements, and leaderboards

-- =====================================================
-- 1. CHAT MESSAGES TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.chat_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sender_username TEXT,
    channel TEXT NOT NULL DEFAULT 'public',
    message_type TEXT NOT NULL DEFAULT 'text',
    content TEXT NOT NULL,
    metadata JSONB,
    sender_latitude DOUBLE PRECISION,
    sender_longitude DOUBLE PRECISION,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for chat messages
CREATE INDEX IF NOT EXISTS idx_chat_messages_channel ON public.chat_messages(channel);
CREATE INDEX IF NOT EXISTS idx_chat_messages_sender ON public.chat_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_created_at ON public.chat_messages(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_chat_messages_location ON public.chat_messages(sender_latitude, sender_longitude)
    WHERE sender_latitude IS NOT NULL AND sender_longitude IS NOT NULL;

-- Enable RLS
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- RLS Policies for chat_messages
CREATE POLICY "Anyone can read public channel messages" ON public.chat_messages
    FOR SELECT USING (channel = 'public');

CREATE POLICY "Users can read their own messages" ON public.chat_messages
    FOR SELECT USING (auth.uid() = sender_id);

CREATE POLICY "Users can insert their own messages" ON public.chat_messages
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own messages" ON public.chat_messages
    FOR UPDATE USING (auth.uid() = sender_id);

-- =====================================================
-- 2. USER PRESENCE TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.user_presence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
    username TEXT,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    latitude DOUBLE PRECISION,
    longitude DOUBLE PRECISION,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for user presence
CREATE INDEX IF NOT EXISTS idx_user_presence_user ON public.user_presence(user_id);
CREATE INDEX IF NOT EXISTS idx_user_presence_online ON public.user_presence(is_online) WHERE is_online = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_presence_location ON public.user_presence(latitude, longitude)
    WHERE latitude IS NOT NULL AND longitude IS NOT NULL;

-- Enable RLS
ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_presence
CREATE POLICY "Anyone can read user presence" ON public.user_presence
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can update their own presence" ON public.user_presence
    FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- 3. USER ACHIEVEMENTS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.user_achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id TEXT NOT NULL,
    current_value INTEGER DEFAULT 0,
    is_completed BOOLEAN DEFAULT FALSE,
    completed_at TIMESTAMP WITH TIME ZONE,
    reward_claimed BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, achievement_id)
);

-- Indexes for user achievements
CREATE INDEX IF NOT EXISTS idx_user_achievements_user ON public.user_achievements(user_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_achievement ON public.user_achievements(achievement_id);
CREATE INDEX IF NOT EXISTS idx_user_achievements_completed ON public.user_achievements(is_completed)
    WHERE is_completed = TRUE;
CREATE INDEX IF NOT EXISTS idx_user_achievements_unclaimed ON public.user_achievements(is_completed, reward_claimed)
    WHERE is_completed = TRUE AND reward_claimed = FALSE;

-- Enable RLS
ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_achievements
CREATE POLICY "Users can read their own achievements" ON public.user_achievements
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own achievements" ON public.user_achievements
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own achievements" ON public.user_achievements
    FOR UPDATE USING (auth.uid() = user_id);

-- =====================================================
-- 4. LEADERBOARDS TABLE
-- =====================================================

CREATE TABLE IF NOT EXISTS public.leaderboards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    username TEXT,
    type TEXT NOT NULL,
    value INTEGER DEFAULT 0,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE(user_id, type)
);

-- Indexes for leaderboards
CREATE INDEX IF NOT EXISTS idx_leaderboards_type ON public.leaderboards(type);
CREATE INDEX IF NOT EXISTS idx_leaderboards_type_value ON public.leaderboards(type, value DESC);
CREATE INDEX IF NOT EXISTS idx_leaderboards_user ON public.leaderboards(user_id);
CREATE INDEX IF NOT EXISTS idx_leaderboards_updated ON public.leaderboards(updated_at);

-- Enable RLS
ALTER TABLE public.leaderboards ENABLE ROW LEVEL SECURITY;

-- RLS Policies for leaderboards
CREATE POLICY "Anyone can read leaderboards" ON public.leaderboards
    FOR SELECT USING (TRUE);

CREATE POLICY "Users can update their own leaderboard entries" ON public.leaderboards
    FOR ALL USING (auth.uid() = user_id);

-- =====================================================
-- 5. ENABLE REALTIME FOR CHAT
-- =====================================================

-- Enable realtime for chat_messages table
ALTER PUBLICATION supabase_realtime ADD TABLE public.chat_messages;

-- =====================================================
-- 6. FUNCTIONS
-- =====================================================

-- Function to get nearby players (using approximate distance calculation)
CREATE OR REPLACE FUNCTION get_nearby_players(
    p_latitude DOUBLE PRECISION,
    p_longitude DOUBLE PRECISION,
    p_radius_meters DOUBLE PRECISION,
    p_exclude_user_id UUID
)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    distance DOUBLE PRECISION,
    last_active_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        up.user_id,
        up.username,
        -- Approximate distance calculation using Haversine formula
        (6371000 * acos(
            cos(radians(p_latitude)) * cos(radians(up.latitude)) *
            cos(radians(up.longitude) - radians(p_longitude)) +
            sin(radians(p_latitude)) * sin(radians(up.latitude))
        )) AS distance,
        up.last_seen_at
    FROM public.user_presence up
    WHERE up.is_online = TRUE
      AND up.user_id != p_exclude_user_id
      AND up.latitude IS NOT NULL
      AND up.longitude IS NOT NULL
      -- Quick bounding box filter first
      AND up.latitude BETWEEN p_latitude - (p_radius_meters / 111000.0)
                          AND p_latitude + (p_radius_meters / 111000.0)
      AND up.longitude BETWEEN p_longitude - (p_radius_meters / (111000.0 * cos(radians(p_latitude))))
                           AND p_longitude + (p_radius_meters / (111000.0 * cos(radians(p_latitude))))
    HAVING (6371000 * acos(
        cos(radians(p_latitude)) * cos(radians(up.latitude)) *
        cos(radians(up.longitude) - radians(p_longitude)) +
        sin(radians(p_latitude)) * sin(radians(up.latitude))
    )) <= p_radius_meters
    ORDER BY distance;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get leaderboard with ranks
CREATE OR REPLACE FUNCTION get_leaderboard_with_ranks(
    p_type TEXT,
    p_limit INTEGER DEFAULT 50
)
RETURNS TABLE (
    user_id UUID,
    username TEXT,
    value INTEGER,
    rank BIGINT
) AS $$
BEGIN
    RETURN QUERY
    SELECT
        l.user_id,
        l.username,
        l.value,
        ROW_NUMBER() OVER (ORDER BY l.value DESC) AS rank
    FROM public.leaderboards l
    WHERE l.type = p_type
    ORDER BY l.value DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- =====================================================
-- 7. TRIGGERS
-- =====================================================

-- Trigger to update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_achievements_updated_at
    BEFORE UPDATE ON public.user_achievements
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_leaderboards_updated_at
    BEFORE UPDATE ON public.leaderboards
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trigger_user_presence_updated_at
    BEFORE UPDATE ON public.user_presence
    FOR EACH ROW
    EXECUTE FUNCTION update_updated_at();

-- =====================================================
-- 8. COMMENTS
-- =====================================================

COMMENT ON TABLE public.chat_messages IS '聊天消息表 - 存储所有频道的聊天消息';
COMMENT ON TABLE public.user_presence IS '用户在线状态表 - 追踪用户在线状态和位置';
COMMENT ON TABLE public.user_achievements IS '用户成就进度表 - 记录每个用户的成就完成情况';
COMMENT ON TABLE public.leaderboards IS '排行榜表 - 存储各类排行榜数据';

COMMENT ON COLUMN public.chat_messages.channel IS '频道类型: public, nearby, territory, trade';
COMMENT ON COLUMN public.chat_messages.message_type IS '消息类型: text, system, location, trade, image, voice';
COMMENT ON COLUMN public.leaderboards.type IS '排行榜类型: territory_count, territory_area, trade_volume, etc.';
