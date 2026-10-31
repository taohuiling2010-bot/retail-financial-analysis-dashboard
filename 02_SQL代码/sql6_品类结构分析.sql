-- ============================================================
-- SQL 6：品类收入结构与折扣依赖度分析
-- 分析周期：2017-08-01 ~ 2017-08-30
-- 输出：一级/二级品类的收入贡献、折扣率、ABC等级
-- 数据清洗：过滤"优惠券"等非销售商品记录
-- 品类口径：按 categoryID1 + categoryID2 分组；源数据中同一编码对应多个名称、
--   名称与商品不符，故不使用品类名称
-- ABC分类：累计收入占比≤80%为A类（核心品类），≤95%为B类，其余C类
-- 折扣依赖：与整体综合折扣率比较，偏离 ≥ +5 个百分点记为高折扣依赖
-- ============================================================

WITH category_sales AS (
    SELECT
        g.categoryID1,
        g.categoryID2,
        SUM(i.AMT)   AS 实际收入,
        SUM(i.pAMT)  AS 促销折扣额,
        SUM(i.mpAMT) AS 会员折扣额,
        SUM(i.QTY)   AS 销售件数,
        COUNT(DISTINCT i.salesNo) AS 订单数
    FROM fct_sales_item i
    INNER JOIN dim_goods g ON i.goodsID = g.dimGoodsID
    WHERE i.dimDateID BETWEEN 20170801 AND 20170830
      AND g.name NOT LIKE '%优惠券%'
      AND g.name NOT LIKE '%赠券%'
      AND g.name NOT LIKE '%代金券%'
    GROUP BY g.categoryID1, g.categoryID2
),
total_revenue AS (
    SELECT SUM(实际收入) AS 总收入,
           (SUM(促销折扣额) + SUM(会员折扣额))
             / NULLIF(SUM(实际收入) + SUM(促销折扣额) + SUM(会员折扣额), 0) * 100 AS 整体折扣率
    FROM category_sales
),
ranked AS (
    SELECT
        cs.*,
        tr.总收入,
        tr.整体折扣率,
        -- 收入占比
        ROUND(cs.实际收入 / NULLIF(tr.总收入, 0) * 100, 2) AS 收入占比,
        -- 累计收入占比（用于ABC分类）；品类编码作为并列时的决胜字段
        ROUND(SUM(cs.实际收入) OVER (
                  ORDER BY cs.实际收入 DESC, cs.categoryID1, cs.categoryID2
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
              ) / NULLIF(tr.总收入, 0) * 100, 2) AS 累计收入占比,
        -- 品类综合折扣率
        ROUND((cs.促销折扣额 + cs.会员折扣额)
              / NULLIF(cs.实际收入 + cs.促销折扣额 + cs.会员折扣额, 0) * 100, 2) AS 综合折扣率,
        -- 每笔含该品类的订单中，该品类贡献的收入（不是顾客客单价）
        ROUND(cs.实际收入 / NULLIF(cs.订单数, 0), 2) AS 品类单均贡献
    FROM category_sales cs
    CROSS JOIN total_revenue tr
)
SELECT
    categoryID1 AS 一级品类编码,
    categoryID2 AS 二级品类编码,
    实际收入, 促销折扣额, 会员折扣额, 销售件数, 订单数,
    收入占比, 累计收入占比, 综合折扣率, 品类单均贡献,
    ROUND(整体折扣率, 2) AS 整体折扣率,
    -- ABC 分类
    CASE
        WHEN 累计收入占比 <= 80 THEN 'A类（核心）'
        WHEN 累计收入占比 <= 95 THEN 'B类（重要）'
        ELSE 'C类（长尾）'
    END AS ABC等级,
    -- 折扣依赖：与整体折扣率的偏离
    ROUND(综合折扣率 - 整体折扣率, 2) AS 折扣率偏离_百分点,
    CASE
        WHEN 综合折扣率 - 整体折扣率 >= 5 THEN '高折扣依赖'
        WHEN 综合折扣率 > 整体折扣率      THEN '略高于整体'
        ELSE '不高于整体'
    END AS 折扣依赖度
FROM ranked
ORDER BY 实际收入 DESC;
