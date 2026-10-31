-- ============================================================
-- SQL 4：商品收入贡献度与折扣依赖度分析（门店视角）
-- 分析周期：2017-08-01 ~ 2017-08-30
-- 门店范围：仅花桥店（BJ01）、广场店（HD01）；东城店、上海店分析期内无任何销售（见 SQL 7）
-- 数据清洗：过滤"优惠券"等非销售商品记录
-- 关键指标：收入贡献排名 + 折扣率（识别"高折扣依赖"商品）
-- 阈值依据：8月门店×商品折扣率分布（约2.03万个组合，已剔除券类）
--   中位数约2.5%，第90百分位5.42%，最高55.06%
--   10%约为中位数的4倍、第90百分位的近2倍，只标记极端依赖折扣的商品
-- 低动销口径：只在有销售的商品中按收入从低到高排名；
--   零销售商品不参与排名——商品维表为全公司档案，缺少门店铺货数据，
--   无法区分"未铺货"与"铺货未售出"，零销售数量见 SQL 7
-- 品类口径：输出品类编码，不输出品类名称（源数据名称与商品不符，见 SQL 6）
-- ============================================================

WITH shop_scope AS (
    SELECT dimShopID, shopCode, name AS shopName, areaCode, areaName
    FROM dim_shop
    WHERE shopCode IN ('HD01', 'BJ01')
),
goods_filtered AS (
    -- 上游过滤非销售商品（POS系统优惠券等）
    SELECT dimGoodsID, name AS goodsName,
           categoryID1, categoryID2, branName
    FROM dim_goods
    WHERE name NOT LIKE '%优惠券%'
      AND name NOT LIKE '%赠券%'
      AND name NOT LIKE '%代金券%'
),
goods_shop_matrix AS (
    SELECT s.dimShopID, s.shopCode, s.shopName, s.areaCode, s.areaName,
           g.dimGoodsID, g.goodsName, g.categoryID1, g.categoryID2, g.branName
    FROM shop_scope s
    CROSS JOIN goods_filtered g
),
sales_agg AS (
    SELECT a.dimShopID, a.goodsID,
           SUM(a.AMT)   AS 实际收入,
           SUM(a.pAMT)  AS 促销折扣额,
           SUM(a.mpAMT) AS 会员折扣额,
           SUM(a.QTY)   AS 销售件数
    FROM fct_sales_item a
    INNER JOIN goods_filtered g ON a.goodsID = g.dimGoodsID
    WHERE a.dimDateID BETWEEN 20170801 AND 20170830
    GROUP BY a.dimShopID, a.goodsID
),
ranked AS (
    SELECT
        m.areaCode AS 大区编码,
        m.areaName AS 大区名称,
        m.shopCode AS 门店编码,
        m.shopName AS 门店名称,
        m.dimGoodsID AS 商品编码,
        m.goodsName  AS 商品名称,
        m.categoryID1 AS 一级品类编码,
        m.categoryID2 AS 二级品类编码,
        m.branName AS 品牌,
        COALESCE(sa.实际收入, 0)   AS 实际收入,
        COALESCE(sa.促销折扣额, 0) AS 促销折扣额,
        COALESCE(sa.会员折扣额, 0) AS 会员折扣额,
        COALESCE(sa.销售件数, 0)   AS 销售件数,
        -- 单品综合折扣率
        ROUND(
            (COALESCE(sa.促销折扣额, 0) + COALESCE(sa.会员折扣额, 0))
            / NULLIF(COALESCE(sa.实际收入, 0)
                   + COALESCE(sa.促销折扣额, 0)
                   + COALESCE(sa.会员折扣额, 0), 0) * 100, 2
        ) AS 综合折扣率,
        -- 商品状态标签
        CASE
            WHEN sa.实际收入 IS NULL THEN '零销售'
            ELSE '有销售'
        END AS 销售状态,
        -- 收入贡献排名（畅销）；商品编码作为并列时的决胜字段，保证结果可复现
        ROW_NUMBER() OVER (
            PARTITION BY m.shopCode
            ORDER BY COALESCE(sa.实际收入, 0) DESC,
                     m.dimGoodsID
        ) AS 收入贡献排名,
        -- 低动销排名：有销售的商品按收入从低到高排，零销售商品排到最后
        ROW_NUMBER() OVER (
            PARTITION BY m.shopCode
            ORDER BY
                CASE WHEN sa.实际收入 IS NULL THEN 1 ELSE 0 END,
                COALESCE(sa.实际收入, 0) ASC,
                m.dimGoodsID
        ) AS 低动销排名
    FROM goods_shop_matrix m
    LEFT JOIN sales_agg sa
        ON sa.dimShopID = m.dimShopID AND sa.goodsID = m.dimGoodsID
)
SELECT
    大区编码, 大区名称, 门店编码, 门店名称,
    商品编码, 商品名称, 一级品类编码, 二级品类编码, 品牌,
    实际收入, 促销折扣额, 会员折扣额, 销售件数,
    综合折扣率, 销售状态,
    收入贡献排名, 低动销排名,
    -- 商品分类：基于收入贡献 × 折扣依赖
    CASE
        WHEN 收入贡献排名 <= 20 AND 综合折扣率 < 10 THEN '明星商品（高收入低折扣）'
        WHEN 收入贡献排名 <= 20 AND 综合折扣率 >= 10 THEN '促销依赖（高收入高折扣）'
        WHEN 低动销排名 <= 20 THEN '低动销（有销售、收入最低）'
    END AS 商品分类,
    CASE
        WHEN 收入贡献排名 <= 20 AND 低动销排名 <= 20 THEN '收入TOP20&低动销TOP20'
        WHEN 收入贡献排名 <= 20 THEN '收入TOP20'
        WHEN 低动销排名 <= 20 THEN '低动销TOP20'
    END AS 榜单标签
FROM ranked
WHERE 收入贡献排名 <= 20 OR 低动销排名 <= 20
ORDER BY 门店编码,
         CASE WHEN 收入贡献排名 <= 20 THEN 0 ELSE 1 END,
         收入贡献排名,
         低动销排名;
