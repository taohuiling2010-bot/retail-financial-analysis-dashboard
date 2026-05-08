-- ============================================================
-- SQL 5：会员价值与客户经济性分析
-- 分析周期：2017-08-01 ~ 2017-08-30
-- 会员判定：fct_sales.dimMemberID > 0 = 会员订单，= 0 为非会员
-- 输出：会员/非会员收入对比、客单价对比、会员细分（新/老）
-- ============================================================

WITH order_level AS (
    SELECT
        h.salesID,
        h.salesNo,
        h.dimShopID,
        h.dimDateID,
        h.dimMemberID,
        CASE WHEN h.dimMemberID > 0 THEN '会员' ELSE '非会员' END AS 客户类型,
        CASE
            WHEN h.dimMemberID = 0 THEN NULL
            WHEN m.firstShoppingDate IS NULL THEN '无首购记录'
            WHEN CAST(m.firstShoppingDate AS UNSIGNED) BETWEEN 20170801 AND 20170830 THEN '新会员'
            ELSE '老会员'
        END AS 会员细分
    FROM fct_sales h
    LEFT JOIN dim_member m ON h.dimMemberID = m.dimMemberID
    WHERE h.dimDateID BETWEEN 20170801 AND 20170830
),
order_amount AS (
    SELECT
        i.salesID,
        SUM(i.AMT)   AS 订单收入,
        SUM(i.pAMT)  AS 订单促销折扣,
        SUM(i.mpAMT) AS 订单会员折扣,
        SUM(i.QTY)   AS 订单件数,
        -- 新增：每个订单的SKU数（不同商品数）
        COUNT(DISTINCT i.goodsID) AS 订单SKU数
    FROM fct_sales_item i
    WHERE i.dimDateID BETWEEN 20170801 AND 20170830
    GROUP BY i.salesID
)
-- 主结果1：会员 vs 非会员总览
SELECT
    o.客户类型 AS 维度值,
    '客户类型' AS 维度,
    COUNT(*) AS 订单数,
    SUM(oa.订单收入)  AS 实际收入,
    SUM(oa.订单促销折扣) AS 促销折扣额,
    SUM(oa.订单会员折扣) AS 会员折扣额,
    SUM(oa.订单件数) AS 销售件数,
    ROUND(SUM(oa.订单收入) / NULLIF(COUNT(*), 0), 2) AS 客单价,
    ROUND(SUM(oa.订单件数) * 1.0 / NULLIF(COUNT(*), 0), 2) AS 件数连带率,
    ROUND(SUM(oa.订单SKU数) * 1.0 / NULLIF(COUNT(*), 0), 2) AS SKU连带率,
    ROUND((SUM(oa.订单促销折扣) + SUM(oa.订单会员折扣))
          / NULLIF(SUM(oa.订单收入) + SUM(oa.订单促销折扣) + SUM(oa.订单会员折扣), 0) * 100, 2) AS 综合折扣率
FROM order_level o
INNER JOIN order_amount oa ON o.salesID = oa.salesID
GROUP BY o.客户类型

UNION ALL

-- 主结果2：会员细分（新/老会员）
SELECT
    o.会员细分 AS 维度值,
    '会员细分' AS 维度,
    COUNT(*) AS 订单数,
    SUM(oa.订单收入)  AS 实际收入,
    SUM(oa.订单促销折扣) AS 促销折扣额,
    SUM(oa.订单会员折扣) AS 会员折扣额,
    SUM(oa.订单件数) AS 销售件数,
    ROUND(SUM(oa.订单收入) / NULLIF(COUNT(*), 0), 2) AS 客单价,
    ROUND(SUM(oa.订单件数) * 1.0 / NULLIF(COUNT(*), 0), 2) AS 件数连带率,
    ROUND(SUM(oa.订单SKU数) * 1.0 / NULLIF(COUNT(*), 0), 2) AS SKU连带率,
    ROUND((SUM(oa.订单促销折扣) + SUM(oa.订单会员折扣))
          / NULLIF(SUM(oa.订单收入) + SUM(oa.订单促销折扣) + SUM(oa.订单会员折扣), 0) * 100, 2) AS 综合折扣率
FROM order_level o
INNER JOIN order_amount oa ON o.salesID = oa.salesID
WHERE o.会员细分 IS NOT NULL
GROUP BY o.会员细分

ORDER BY 维度, 实际收入 DESC;
