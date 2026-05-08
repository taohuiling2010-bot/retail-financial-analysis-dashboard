-- ============================================================
-- SQL 6：品类收入结构与折扣依赖度分析
-- 分析周期：2017-08-01 ~ 2017-08-30
-- 输出：一级/二级品类的收入贡献、折扣率、ABC等级
-- ABC分类：累计收入占比≤80%为A类（核心品类），≤95%为B类，其余C类
-- ============================================================

WITH category_sales AS (
    SELECT
        g.categoryID1,  g.categoryName1,
        g.categoryID2,  g.categoryName2,
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
    GROUP BY g.categoryID1, g.categoryName1, g.categoryID2, g.categoryName2
),
total_revenue AS (
    SELECT SUM(实际收入) AS 总收入 FROM category_sales
),
ranked AS (
    SELECT
        cs.*,
        tr.总收入,
        -- 收入占比
        ROUND(cs.实际收入 / NULLIF(tr.总收入, 0) * 100, 2) AS 收入占比,
        -- 累计收入占比（用于ABC分类）
        ROUND(SUM(cs.实际收入) OVER (
                  ORDER BY cs.实际收入 DESC
                  ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
              ) / NULLIF(tr.总收入, 0) * 100, 2) AS 累计收入占比,
        -- 品类综合折扣率
        ROUND((cs.促销折扣额 + cs.会员折扣额)
              / NULLIF(cs.实际收入 + cs.促销折扣额 + cs.会员折扣额, 0) * 100, 2) AS 综合折扣率,
        ROUND(cs.实际收入 / NULLIF(cs.订单数, 0), 2) AS 客单价
    FROM category_sales cs
    CROSS JOIN total_revenue tr
)
SELECT
    categoryID1   AS 一级品类编码,
    categoryName1 AS 一级品类,
    categoryID2   AS 二级品类编码,
    categoryName2 AS 二级品类,
    实际收入, 促销折扣额, 会员折扣额, 销售件数, 订单数,
    收入占比, 累计收入占比, 综合折扣率, 客单价,
    -- ABC 分类
    CASE
        WHEN 累计收入占比 <= 80 THEN 'A类（核心）'
        WHEN 累计收入占比 <= 95 THEN 'B类（重要）'
        ELSE 'C类（长尾）'
    END AS ABC等级,
    -- 折扣依赖标签
    CASE
        WHEN 综合折扣率 >= 15 THEN '高折扣依赖'
        WHEN 综合折扣率 >= 5  THEN '中等折扣'
        ELSE '低折扣（价格坚挺）'
    END AS 折扣依赖度
FROM ranked
ORDER BY 实际收入 DESC;
