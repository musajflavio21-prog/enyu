-- =============================================
-- 交易系统数据库表
-- Trade System Database Tables
-- =============================================

-- =============================================
-- 1. trade_offers 表 (挂单表)
-- =============================================
CREATE TABLE trade_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES auth.users(id),
    owner_username TEXT,
    offering_items JSONB NOT NULL,
    requesting_items JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    completed_by_user_id UUID REFERENCES auth.users(id),
    completed_by_username TEXT
);

-- 添加字段注释
COMMENT ON TABLE trade_offers IS '交易挂单表';
COMMENT ON COLUMN trade_offers.id IS '挂单唯一ID';
COMMENT ON COLUMN trade_offers.owner_id IS '发布者用户ID';
COMMENT ON COLUMN trade_offers.owner_username IS '发布者用户名';
COMMENT ON COLUMN trade_offers.offering_items IS '出售的物品列表 (JSON)';
COMMENT ON COLUMN trade_offers.requesting_items IS '期望获得的物品列表 (JSON)';
COMMENT ON COLUMN trade_offers.status IS '状态: active/completed/cancelled/expired';
COMMENT ON COLUMN trade_offers.message IS '附加留言';
COMMENT ON COLUMN trade_offers.created_at IS '创建时间';
COMMENT ON COLUMN trade_offers.expires_at IS '过期时间';
COMMENT ON COLUMN trade_offers.completed_at IS '完成时间';
COMMENT ON COLUMN trade_offers.completed_by_user_id IS '接受者用户ID';
COMMENT ON COLUMN trade_offers.completed_by_username IS '接受者用户名';

-- 索引
CREATE INDEX idx_trade_offers_owner ON trade_offers(owner_id);
CREATE INDEX idx_trade_offers_status ON trade_offers(status);
CREATE INDEX idx_trade_offers_expires ON trade_offers(expires_at);
CREATE INDEX idx_trade_offers_created ON trade_offers(created_at DESC);

-- =============================================
-- 2. trade_history 表 (交易历史表)
-- =============================================
CREATE TABLE trade_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    offer_id UUID REFERENCES trade_offers(id),
    seller_id UUID NOT NULL REFERENCES auth.users(id),
    seller_username TEXT,
    buyer_id UUID NOT NULL REFERENCES auth.users(id),
    buyer_username TEXT,
    items_exchanged JSONB NOT NULL,
    completed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    seller_rating INTEGER CHECK (seller_rating BETWEEN 1 AND 5),
    buyer_rating INTEGER CHECK (buyer_rating BETWEEN 1 AND 5),
    seller_comment TEXT,
    buyer_comment TEXT
);

-- 添加字段注释
COMMENT ON TABLE trade_history IS '交易历史表';
COMMENT ON COLUMN trade_history.id IS '历史记录唯一ID';
COMMENT ON COLUMN trade_history.offer_id IS '关联的挂单ID';
COMMENT ON COLUMN trade_history.seller_id IS '卖家用户ID';
COMMENT ON COLUMN trade_history.seller_username IS '卖家用户名';
COMMENT ON COLUMN trade_history.buyer_id IS '买家用户ID';
COMMENT ON COLUMN trade_history.buyer_username IS '买家用户名';
COMMENT ON COLUMN trade_history.items_exchanged IS '交换的物品详情 (JSON)';
COMMENT ON COLUMN trade_history.completed_at IS '完成时间';
COMMENT ON COLUMN trade_history.seller_rating IS '卖家评分 (1-5)';
COMMENT ON COLUMN trade_history.buyer_rating IS '买家评分 (1-5)';
COMMENT ON COLUMN trade_history.seller_comment IS '卖家评价';
COMMENT ON COLUMN trade_history.buyer_comment IS '买家评价';

-- 索引
CREATE INDEX idx_trade_history_seller ON trade_history(seller_id);
CREATE INDEX idx_trade_history_buyer ON trade_history(buyer_id);
CREATE INDEX idx_trade_history_offer ON trade_history(offer_id);
CREATE INDEX idx_trade_history_completed ON trade_history(completed_at DESC);

-- =============================================
-- 3. RLS 策略 - trade_offers
-- =============================================
ALTER TABLE trade_offers ENABLE ROW LEVEL SECURITY;

-- 所有登录用户可查看 active 挂单，或者查看自己的所有挂单
CREATE POLICY "view_active_offers" ON trade_offers
    FOR SELECT
    USING (status = 'active' OR owner_id = auth.uid());

-- 只能插入自己的挂单
CREATE POLICY "insert_own_offers" ON trade_offers
    FOR INSERT
    WITH CHECK (owner_id = auth.uid());

-- 只能更新自己的挂单（取消）或接受别人的 active 挂单
CREATE POLICY "update_offers" ON trade_offers
    FOR UPDATE
    USING (owner_id = auth.uid() OR status = 'active');

-- =============================================
-- 4. RLS 策略 - trade_history
-- =============================================
ALTER TABLE trade_history ENABLE ROW LEVEL SECURITY;

-- 只能查看自己参与的交易
CREATE POLICY "view_own_history" ON trade_history
    FOR SELECT
    USING (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 只能插入自己参与的交易历史
CREATE POLICY "insert_own_history" ON trade_history
    FOR INSERT
    WITH CHECK (seller_id = auth.uid() OR buyer_id = auth.uid());

-- 只能更新自己的评价
CREATE POLICY "update_own_rating" ON trade_history
    FOR UPDATE
    USING (seller_id = auth.uid() OR buyer_id = auth.uid());
