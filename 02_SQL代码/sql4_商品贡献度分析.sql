-- ============================================================
-- SQL 4：商品收入贡献度与折扣依赖度分析（门店视角）
-- 分析周期：2017-08-01 ~ 2017-08-30
-- 数据清洗：过滤"优惠券"等非销售商品记录
-- 关键指标：收入贡献排名 + 折扣率（识别"高折扣依赖"商品）
-- ============================================================

WITH shop_scope AS (
    SELECT dimShopID, shopCode, name AS shopName, areaCode, areaName
    FROM dim_shop
    WHERE shopCode IN ('HD01', 'BJ01', 'HD02', 'BJ0002')
),
goods_filtered AS (
    -- 上游过滤非销售商品（POS系统优惠券等）
    SELECT dimGoodsID, name AS goodsName,
           categoryName1, categoryName2, branName
    FROM dim_goods
    WHERE name NOT LIKE '%优惠券%'
      AND name NOT LIKE '%赠券%'
      AND name NOT LIKE '%代金券%'
),
goods_shop_matrix AS (
    SELECT s.dimShopID, s.shopCode, s.shopName, s.areaCode, s.areaName,
           g.dimGoodsID, g.goodsName, g.categoryName1, g.categoryName2, g.branName
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
        m.categoryName1 AS 一级品类,
        m.categoryName2 AS 二级品类,
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
        -- 收入贡献排名（畅销）
        ROW_NUMBER() OVER (
            PARTITION BY m.shopCode
            ORDER BY COALESCE(sa.实际收入, 0) DESC
        ) AS 收入贡献排名,
        -- 滞销排名（零销售优先）
        ROW_NUMBER() OVER (
            PARTITION BY m.shopCode
            ORDER BY
                CASE WHEN sa.实际收入 IS NULL THEN 0 ELSE 1 END,
                COALESCE(sa.实际收入, 0) ASC
        ) AS 滞销排名
    FROM goods_shop_matrix m
    LEFT JOIN sales_agg sa
        ON sa.dimShopID = m.dimShopID AND sa.goodsID = m.dimGoodsID
)
SELECT
    大区编码, 大区名称, 门店编码, 门店名称,
    商品编码, 商品名称, 一级品类, 二级品类, 品牌,
    实际收入, 促销折扣额, 会员折扣额, 销售件数,
    综合折扣率, 销售状态,
    收入贡献排名, 滞销排名,
    -- 四象限标签：基于收入贡献 × 折扣依赖
    CASE
        WHEN 收入贡献排名 <= 20 AND 综合折扣率 < 10 THEN '明星商品（高收入低折扣）'
        WHEN 收入贡献排名 <= 20 AND 综合折扣率 >= 10 THEN '促销依赖（高收入高折扣）'
        WHEN 滞销排名 <= 20 THEN '清库重点（低收入）'
    END AS 商品分类,
    CASE
        WHEN 收入贡献排名 <= 20 AND 滞销排名 <= 20 THEN '畅销&滞销'
        WHEN 收入贡献排名 <= 20 THEN '收入TOP20'
        WHEN 滞销排名 <= 20 THEN '滞销TOP20'
    END AS 榜单标签
FROM ranked
WHERE 收入贡献排名 <= 20 OR 滞销排名 <= 20
ORDER BY 门店编码,
         CASE WHEN 收入贡献排名 <= 20 THEN 0 ELSE 1 END,
         收入贡献排名,
         滞销排名;
