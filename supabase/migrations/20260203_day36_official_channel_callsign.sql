-- ============================================
-- EarthLord Day 36: 官方频道与呼号系统
-- 创建官方频道记录、添加呼号字段
-- ============================================

-- 1. 创建官方频道记录
-- 使用固定 UUID 确保唯一性和客户端引用
INSERT INTO public.communication_channels (
    id, creator_id, channel_type, channel_code, name, description, is_active, member_count
) VALUES (
    '00000000-0000-0000-0000-000000000000',
    '00000000-0000-0000-0000-000000000001',
    'official', 'OFFICIAL-001', '末日广播站',
    '官方公告、生存指南、任务发布、紧急警报',
    true, 0
) ON CONFLICT (id) DO NOTHING;

-- 2. 添加呼号字段到 profiles 表
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS callsign TEXT;

-- 3. 创建呼号唯一索引（允许 NULL）
CREATE UNIQUE INDEX IF NOT EXISTS idx_profiles_callsign ON public.profiles (callsign) WHERE callsign IS NOT NULL;

-- 4. 添加呼号检查约束（2-16字符）
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS check_callsign_length;
ALTER TABLE public.profiles ADD CONSTRAINT check_callsign_length
    CHECK (callsign IS NULL OR (char_length(callsign) >= 2 AND char_length(callsign) <= 16));

-- 5. 更新 send_channel_message 函数支持消息分类
CREATE OR REPLACE FUNCTION send_channel_message(
    p_channel_id UUID,
    p_content TEXT,
    p_latitude DOUBLE PRECISION DEFAULT NULL,
    p_longitude DOUBLE PRECISION DEFAULT NULL,
    p_device_type TEXT DEFAULT NULL,
    p_callsign TEXT DEFAULT '匿名幸存者',
    p_category TEXT DEFAULT NULL  -- Day 36: 新增消息分类参数
)
RETURNS UUID AS $$
DECLARE
    v_message_id UUID;
    v_sender_id UUID;
    v_location GEOGRAPHY(POINT, 4326);
    v_metadata JSONB;
BEGIN
    v_sender_id := auth.uid();

    -- 检查是否订阅了频道
    IF NOT EXISTS (
        SELECT 1 FROM public.channel_subscriptions
        WHERE channel_id = p_channel_id AND user_id = v_sender_id
    ) THEN
        RAISE EXCEPTION '您未订阅此频道，无法发送消息';
    END IF;

    -- 构建位置
    IF p_latitude IS NOT NULL AND p_longitude IS NOT NULL THEN
        v_location := ST_SetSRID(ST_MakePoint(p_longitude, p_latitude), 4326)::GEOGRAPHY;
    END IF;

    -- 构建元数据（包含设备类型和分类）
    v_metadata := jsonb_build_object(
        'device_type', COALESCE(p_device_type, 'unknown'),
        'category', p_category
    );

    -- 插入消息
    INSERT INTO public.channel_messages (
        channel_id, sender_id, sender_callsign, content, sender_location, metadata
    )
    VALUES (
        p_channel_id, v_sender_id, p_callsign, p_content, v_location, v_metadata
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 6. 创建官方广播函数（管理员专用）
CREATE OR REPLACE FUNCTION broadcast_official_message(
    p_content TEXT,
    p_category TEXT DEFAULT 'news'
)
RETURNS UUID AS $$
DECLARE
    v_message_id UUID;
    v_official_channel_id UUID := '00000000-0000-0000-0000-000000000000';
    v_metadata JSONB;
BEGIN
    -- 构建元数据
    v_metadata := jsonb_build_object(
        'device_type', 'official',
        'category', p_category
    );

    -- 插入消息（绕过订阅检查）
    INSERT INTO public.channel_messages (
        channel_id, sender_id, sender_callsign, content, metadata
    )
    VALUES (
        v_official_channel_id, NULL, '末日广播站', p_content, v_metadata
    )
    RETURNING message_id INTO v_message_id;

    RETURN v_message_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 7. 添加 RLS 策略允许查看官方频道消息（无需订阅）
DROP POLICY IF EXISTS "所有人可以查看官方频道消息" ON public.channel_messages;
CREATE POLICY "所有人可以查看官方频道消息" ON public.channel_messages
    FOR SELECT TO authenticated
    USING (channel_id = '00000000-0000-0000-0000-000000000000');

-- 完成！
SELECT 'Day 36 数据库配置完成: 官方频道 + 呼号系统' AS status;
