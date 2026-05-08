-- ============================================================
-- SQL 1：大区收入质量与折扣结构 MTD 环比分析
-- 本期：2017-08-01 ~ 2017-08-30（30天）
-- 上期：2017-07-01 ~ 2017-07-30（30天，同口径）
-- 核心：吊牌额 -> 促销折扣 -> 会员折扣 -> 实际收入
-- ============================================================

WITH period_config AS (
    SELECT
        20170801 AS curr_start, 20170830 AS curr_end,
        20170701 AS prev_start, 20170730 AS prev_end
),
sales_agg AS (
    SELECT
        b.areaCode AS 大区编码,
        b.areaName AS 大区名称,
        -- 本期
        SUM(CASE WHEN a.dimDateID BETWEEN p.curr_start AND p.curr_end THEN a.AMT  ELSE 0 END) AS 实际收入,
        SUM(CASE WHEN a.dimDateID BETWEEN p.curr_start AND p.curr_end THEN a.pAMT ELSE 0 END) AS 促销折扣额,
        SUM(CASE WHEN a.dimDateID BETWEEN p.curr_start AND p.curr_end THEN a.mpAMT ELSE 0 END) AS 会员折扣额,
        SUM(CASE WHEN a.dimDateID BETWEEN p.curr_start AND p.curr_end THEN a.QTY  ELSE 0 END) AS 销售件数,
        COUNT(DISTINCT CASE WHEN a.dimDateID BETWEEN p.curr_start AND p.curr_end THEN a.salesNo END) AS 订单数,
        -- 新增：本期 SKU连带率分子（每单不同商品数）
        COUNT(DISTINCT CASE WHEN a.dimDateID BETWEEN p.curr_start AND p.curr_end
                            THEN CONCAT(a.salesNo, '-', a.goodsID) END) AS 订单SKU组合数,
        -- 上期
        SUM(CASE WHEN a.dimDateID BETWEEN p.prev_start AND p.prev_end THEN a.AMT  ELSE 0 END) AS 上期实际收入,
        SUM(CASE WHEN a.dimDateID BETWEEN p.prev_start AND p.prev_end THEN a.pAMT ELSE 0 END) AS 上期促销折扣额,
        SUM(CASE WHEN a.dimDateID BETWEEN p.prev_start AND p.prev_end THEN a.mpAMT ELSE 0 END) AS 上期会员折扣额,
        COUNT(DISTINCT CASE WHEN a.dimDateID BETWEEN p.prev_start AND p.prev_end THEN a.salesNo END) AS 上期订单数
    FROM fct_sales_item a
    INNER JOIN dim_shop b ON a.dimShopID = b.dimShopID
    CROSS JOIN period_config p
    WHERE a.dimDateID BETWEEN 20170701 AND 20170830
    GROUP BY b.areaCode, b.areaName
)
SELECT
    大区编码, 大区名称,
    -- 收入结构（本期）
    实际收入 + 促销折扣额 + 会员折扣额 AS 吊牌总额,
    实际收入,
    促销折扣额, 会员折扣额,
    促销折扣额 + 会员折扣额 AS 折扣总额,
    -- 折扣率指标
    ROUND(促销折扣额 / NULLIF(实际收入 + 促销折扣额 + 会员折扣额, 0) * 100, 2) AS 促销折扣率,
    ROUND(会员折扣额 / NULLIF(实际收入 + 促销折扣额 + 会员折扣额, 0) * 100, 2) AS 会员折扣率,
    ROUND((促销折扣额 + 会员折扣额) / NULLIF(实际收入 + 促销折扣额 + 会员折扣额, 0) * 100, 2) AS 综合折扣率,
    ROUND(实际收入 / NULLIF(实际收入 + 促销折扣额 + 会员折扣额, 0) * 100, 2) AS 价格实现率,
    -- 客户经济性
    销售件数, 订单数,
    ROUND(实际收入 / NULLIF(订单数, 0), 2) AS 客单价,
    ROUND(销售件数 * 1.0 / NULLIF(订单数, 0), 2) AS 件数连带率,
    ROUND(订单SKU组合数 * 1.0 / NULLIF(订单数, 0), 2) AS SKU连带率,
    -- MTD 环比
    上期实际收入,
    ROUND((实际收入 - 上期实际收入) / NULLIF(上期实际收入, 0) * 100, 2) AS 收入环比,
    ROUND((订单数 - 上期订单数) / NULLIF(上期订单数, 0) * 100, 2) AS 订单数环比,
    -- 上期综合折扣率（对比折扣率是否在恶化）
    ROUND((上期促销折扣额 + 上期会员折扣额) / NULLIF(上期实际收入 + 上期促销折扣额 + 上期会员折扣额, 0) * 100, 2) AS 上期综合折扣率,
    -- 在最外层 SELECT 末尾加上这几行
    上期促销折扣额,
    上期会员折扣额,
    上期实际收入 + 上期促销折扣额 + 上期会员折扣额 AS 上期吊牌总额,
    ROUND(上期实际收入 / NULLIF(上期实际收入 + 上期促销折扣额 + 上期会员折扣额, 0) * 100, 2) AS 上期价格实现率
FROM sales_agg
ORDER BY 实际收入 DESC;
